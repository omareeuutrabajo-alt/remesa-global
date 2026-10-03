import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacén cifrado para credenciales.
///
/// Android → Keystore · iOS → Keychain · Web → cifrado del navegador.
/// Aquí NUNCA se guardan contraseñas ni PIN en claro: solo tokens opacos.
///
/// Todas las operaciones son tolerantes a fallos de plataforma (keystore
/// corrupto, navegador sin contexto seguro…): ante un error se degrada a
/// "sin sesión" en lugar de dejar la app bloqueada en el splash.
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _kAccess = 'auth.access_token';
  static const _kRefresh = 'auth.refresh_token';
  static const _kBiometric = 'auth.biometric_token';
  static const _kDeviceId = 'device.id';
  static const _kLastEmail = 'auth.last_email';

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[almacén] no se pudo leer "$key": $e');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[almacén] no se pudo guardar "$key": $e');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[almacén] no se pudo borrar "$key": $e');
    }
  }

  Future<String?> get accessToken => _read(_kAccess);
  Future<String?> get refreshToken => _read(_kRefresh);
  Future<String?> get biometricToken => _read(_kBiometric);
  Future<String?> get deviceId => _read(_kDeviceId);
  Future<String?> get lastEmail => _read(_kLastEmail);

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _write(_kAccess, access);
    await _write(_kRefresh, refresh);
  }

  Future<void> saveAccessToken(String token) => _write(_kAccess, token);
  Future<void> saveBiometricToken(String token) => _write(_kBiometric, token);
  Future<void> saveDeviceId(String id) => _write(_kDeviceId, id);
  Future<void> saveLastEmail(String email) => _write(_kLastEmail, email);

  Future<void> clearBiometricToken() => _delete(_kBiometric);

  /// Borra la sesión conservando el identificador del dispositivo
  /// (sigue siendo "de confianza") y el correo para precargar el login.
  Future<void> clearSession() async {
    await _delete(_kAccess);
    await _delete(_kRefresh);
  }

  Future<void> wipe() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[almacén] no se pudo vaciar: $e');
    }
  }
}
