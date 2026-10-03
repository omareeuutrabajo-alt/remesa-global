import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/device_info.dart';
import 'models/auth_models.dart';
import 'models/user_model.dart';

/// Única puerta de entrada a los endpoints de autenticación.
/// La capa de presentación nunca habla con Dio directamente.
class AuthRepository {
  AuthRepository({
    required ApiClient api,
    required SecureStorage storage,
    required DeviceInfo device,
    // ignore: prefer_initializing_formals
  })  : _api = api,
        // ignore: prefer_initializing_formals
        _storage = storage,
        // ignore: prefer_initializing_formals
        _device = device;

  final ApiClient _api;
  final SecureStorage _storage;
  final DeviceInfo _device;

  Future<Map<String, dynamic>> _deviceMeta() async => {
        'deviceId': await _device.deviceId(),
        'deviceName': _device.deviceName,
        'platform': _device.platform,
      };

  /// Guarda los tokens en el almacén cifrado si la respuesta los trae.
  Future<AuthResult> _procesar(Map<String, dynamic> data) async {
    if (data['requiresOtp'] == true) {
      return AuthResult(challenge: OtpChallenge.fromJson(data), nextStep: 'verify_otp');
    }
    final tokensJson = (data['tokens'] as Map?)?.cast<String, dynamic>();
    if (tokensJson != null) {
      final tokens = AuthTokens.fromJson(tokensJson);
      await _storage.saveTokens(access: tokens.accessToken, refresh: tokens.refreshToken);
      return AuthResult(
        tokens: tokens,
        user: (data['user'] as Map?)?.cast<String, dynamic>(),
        nextStep: data['nextStep'] as String?,
      );
    }
    return AuthResult(nextStep: data['nextStep'] as String?);
  }

  // ───────────────── Registro e inicio de sesión ─────────────────

  Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String countryCode,
    required String password,
  }) async {
    final data = await _api.post('/auth/register', skipAuth: true, data: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'countryCode': countryCode,
      'password': password,
      'acceptedTerms': true,
    });
    await _storage.saveLastEmail(email);
    return _procesar(data);
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final data = await _api.post('/auth/login', skipAuth: true, data: {
      'email': email,
      'password': password,
      ...await _deviceMeta(),
    });
    await _storage.saveLastEmail(email);
    return _procesar(data);
  }

  Future<AuthResult> verifyOtp({
    required String challengeId,
    required String code,
    bool trustDevice = true,
  }) async {
    final data = await _api.post('/auth/otp/verify', skipAuth: true, data: {
      'challengeId': challengeId,
      'code': code,
      'trustDevice': trustDevice,
      ...await _deviceMeta(),
    });
    // El reto de recuperación devuelve un token de un solo uso, no sesión.
    if (data['resetToken'] != null) {
      return AuthResult(nextStep: 'reset_password', user: {'resetToken': data['resetToken']});
    }
    return _procesar(data);
  }

  Future<OtpChallenge> resendOtp(String challengeId) async {
    final data = await _api.post('/auth/otp/resend', skipAuth: true, data: {'challengeId': challengeId});
    return OtpChallenge.fromJson({...data, 'challengeId': data['challengeId']});
  }

  // ───────────────── Contraseña ─────────────────

  Future<OtpChallenge?> forgotPassword(String email) async {
    final data = await _api.post('/auth/password/forgot', skipAuth: true, data: {'email': email});
    if (data['challengeId'] == null) return null; // correo inexistente: respuesta genérica
    return OtpChallenge.fromJson(data);
  }

  Future<void> resetPassword({required String resetToken, required String newPassword}) =>
      _api.post('/auth/password/reset', skipAuth: true, data: {
        'resetToken': resetToken,
        'newPassword': newPassword,
      });

  Future<void> changePassword({required String current, required String nueva}) =>
      _api.post('/auth/password/change', data: {
        'currentPassword': current,
        'newPassword': nueva,
      });

  // ───────────────── PIN ─────────────────

  Future<String> setPin(String pin) async {
    final data = await _api.post('/auth/pin', data: {'pin': pin, 'confirmPin': pin});
    return data['nextStep'] as String? ?? 'home';
  }

  Future<bool> verifyPin(String pin) async {
    final data = await _api.post('/auth/pin/verify', data: {'pin': pin});
    return data['verified'] == true;
  }

  // ───────────────── Biometría ─────────────────

  Future<void> enrollBiometric() async {
    final data = await _api.post('/auth/biometric/enroll', data: await _deviceMeta());
    final token = data['biometricToken'] as String?;
    if (token != null) await _storage.saveBiometricToken(token);
  }

  Future<void> disableBiometric() async {
    await _api.post('/auth/biometric/disable', data: await _deviceMeta());
    await _storage.clearBiometricToken();
  }

  Future<bool> get biometricEnrolled async {
    final token = await _storage.biometricToken;
    return token != null && token.isNotEmpty;
  }

  Future<AuthResult> loginWithBiometric() async {
    final token = await _storage.biometricToken;
    if (token == null || token.isEmpty) {
      throw StateError('No hay biometría registrada en este dispositivo');
    }
    final data = await _api.post('/auth/biometric/login', skipAuth: true, data: {
      'deviceId': await _device.deviceId(),
      'biometricToken': token,
    });
    return _procesar(data);
  }

  // ───────────────── Sesión ─────────────────

  Future<AppUser> me() async {
    final data = await _api.get('/auth/me');
    return AppUser.fromJson((data['user'] as Map).cast<String, dynamic>());
  }

  Future<String> nextStep() async {
    final data = await _api.get('/auth/me');
    return data['nextStep'] as String? ?? 'home';
  }

  Future<List<Map<String, dynamic>>> sessions() async {
    final data = await _api.get('/auth/sessions');
    return ((data['sessions'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> logout({bool allDevices = false}) async {
    final refresh = await _storage.refreshToken;
    try {
      await _api.post('/auth/logout', data: {
        'refreshToken': ?refresh,
        'allDevices': allDevices,
      });
    } catch (_) {
      // Da igual: el cierre local es lo que importa para el usuario.
    }
    await _storage.clearSession();
    if (allDevices) await _storage.clearBiometricToken();
  }

  Future<bool> get hasSession async {
    final token = await _storage.refreshToken;
    return token != null && token.isNotEmpty;
  }

  Future<String?> get lastEmail => _storage.lastEmail;
}
