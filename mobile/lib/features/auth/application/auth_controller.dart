import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/device_info.dart';
import '../data/auth_repository.dart';
import '../data/models/user_model.dart';
import 'auth_state.dart';
import 'biometric_service.dart';

/* ───────────────────────── Inyección de dependencias ───────────────────── */

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final deviceInfoProvider =
    Provider<DeviceInfo>((ref) => DeviceInfo(ref.watch(secureStorageProvider)));

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(storage: ref.watch(secureStorageProvider));
  client.onSessionExpired = () => ref.read(authControllerProvider.notifier).sesionExpirada();
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      api: ref.watch(apiClientProvider),
      storage: ref.watch(secureStorageProvider),
      device: ref.watch(deviceInfoProvider),
    ));

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

/// Se sobreescribe en `main()` con la instancia ya cargada.
final preferencesProvider = Provider<AppPreferences>(
  (ref) => throw UnimplementedError('AppPreferences debe inyectarse en main()'),
);

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/* ──────────────────────────── Controlador ──────────────────────────────── */

/// Orquesta todo el módulo de inicio. Las pantallas solo llaman métodos
/// de aquí y observan [AuthState]: nada de lógica en los widgets.
class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repo = ref.read(authRepositoryProvider);
  late final BiometricService _bio = ref.read(biometricServiceProvider);
  AppPreferences get _prefs => ref.read(preferencesProvider);

  DateTime? _ultimaActividad;

  @override
  AuthState build() {
    Future.microtask(arrancar);
    return const AuthState();
  }

  /* ───────────── Arranque ───────────── */

  /// Decide la primera pantalla: onboarding, login o sesión restaurada.
  ///
  /// Pase lo que pase debe terminar en un estado conocido: si algo falla
  /// (almacén inaccesible, API caída) se cae a "invitado" en vez de dejar
  /// la app colgada en el splash.
  /// Tiempo mínimo que se muestra la pantalla de marca al abrir la app.
  /// La restauración corre en paralelo: nunca añade espera si tarda más.
  static const duracionMinimaSplash = Duration(milliseconds: 1100);

  Future<void> arrancar() async {
    final marca = Future<void>.delayed(duracionMinimaSplash);
    try {
      _esperaMarca = marca;
      await _arrancarInterno();
    } catch (e) {
      debugPrint('[auth] fallo al restaurar la sesión: $e');
      await marca;
      state = state.copyWith(status: AuthStatus.invitado, limpiarUsuario: true);
    } finally {
      _esperaMarca = null;
    }
  }

  /// Mientras el splash tiene su tiempo mínimo, los cambios de estado del
  /// arranque esperan a que termine para no provocar un salto brusco.
  Future<void>? _esperaMarca;

  Future<void> _arrancarInterno() async {
    final disponible = await _bio.disponible;
    final registrada = await _repo.biometricEnrolled;

    if (!await _repo.hasSession) {
      await _esperaMarca;
      state = state.copyWith(
        status: AuthStatus.invitado,
        biometriaDisponible: disponible,
        biometriaActiva: registrada && _prefs.biometricEnabled,
      );
      return;
    }

    try {
      final user = await _repo.me();
      final paso = await _repo.nextStep();
      _ultimaActividad = DateTime.now();
      await _esperaMarca;
      state = state.copyWith(
        status: AuthStatus.autenticado,
        user: user,
        nextStep: paso,
        biometriaDisponible: disponible,
        biometriaActiva: registrada && _prefs.biometricEnabled,
      );
    } on ApiException catch (e) {
      // Sin red no tiramos la sesión: pedimos PIN y reintentamos luego.
      if (e.isNetwork) {
        await _esperaMarca;
      state = state.copyWith(status: AuthStatus.bloqueado, biometriaDisponible: disponible);
      } else {
        await _repo.logout();
        await _esperaMarca;
      state = state.copyWith(
          status: AuthStatus.invitado,
          limpiarUsuario: true,
          biometriaDisponible: disponible,
          biometriaActiva: registrada,
        );
      }
    }
  }

  /* ───────────── Registro / Login ───────────── */

  Future<bool> registrar({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String countryCode,
    required String password,
  }) async {
    return _ejecutar(() async {
      final res = await _repo.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        countryCode: countryCode,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.esperandoOtp,
        challenge: res.challenge,
        nextStep: 'verify_otp',
      );
      return true;
    });
  }

  Future<bool> iniciarSesion({required String email, required String password}) async {
    return _ejecutar(() async {
      final res = await _repo.login(email: email, password: password);
      if (res.requiresOtp) {
        state = state.copyWith(
          status: AuthStatus.esperandoOtp,
          challenge: res.challenge,
          nextStep: 'verify_otp',
        );
      } else {
        await _sesionIniciada(res.nextStep);
      }
      return true;
    });
  }

  Future<bool> verificarOtp(String code) async {
    final challenge = state.challenge;
    if (challenge == null) {
      state = state.copyWith(error: 'La verificación expiró. Vuelve a intentarlo.');
      return false;
    }
    return _ejecutar(() async {
      final res = await _repo.verifyOtp(challengeId: challenge.challengeId, code: code);

      if (res.nextStep == 'reset_password') {
        state = state.copyWith(
          status: AuthStatus.invitado,
          resetToken: res.user?['resetToken'] as String?,
          nextStep: 'reset_password',
          limpiarChallenge: true,
        );
        return true;
      }

      await _sesionIniciada(res.nextStep);
      return true;
    });
  }

  Future<bool> reenviarOtp() async {
    final challenge = state.challenge;
    if (challenge == null) return false;
    return _ejecutar(() async {
      final nuevo = await _repo.resendOtp(challenge.challengeId);
      state = state.copyWith(challenge: nuevo, mensaje: 'Te enviamos un código nuevo');
      return true;
    });
  }

  /* ───────────── Recuperación de contraseña ───────────── */

  Future<bool> solicitarRecuperacion(String email) async {
    return _ejecutar(() async {
      final challenge = await _repo.forgotPassword(email);
      if (challenge == null) {
        state = state.copyWith(
          mensaje: 'Si el correo está registrado, recibirás un código en unos segundos.',
        );
        return false;
      }
      state = state.copyWith(
        status: AuthStatus.esperandoOtp,
        challenge: challenge,
        nextStep: 'verify_otp',
      );
      return true;
    });
  }

  Future<bool> restablecerPassword(String nueva) async {
    final token = state.resetToken;
    if (token == null) {
      state = state.copyWith(error: 'El enlace de recuperación expiró.');
      return false;
    }
    return _ejecutar(() async {
      await _repo.resetPassword(resetToken: token, newPassword: nueva);
      state = state.copyWith(
        status: AuthStatus.invitado,
        nextStep: 'login',
        resetToken: null,
        mensaje: 'Contraseña actualizada. Ya puedes iniciar sesión.',
      );
      return true;
    });
  }

  /* ───────────── PIN ───────────── */

  Future<bool> configurarPin(String pin) async {
    return _ejecutar(() async {
      final paso = await _repo.setPin(pin);
      final user = await _repo.me();
      state = state.copyWith(
        status: AuthStatus.autenticado,
        user: user,
        nextStep: paso,
        mensaje: 'PIN configurado',
      );
      return true;
    });
  }

  Future<bool> desbloquearConPin(String pin) async {
    return _ejecutar(() async {
      final ok = await _repo.verifyPin(pin);
      if (ok) {
        _ultimaActividad = DateTime.now();
        final paso = await _repo.nextStep();
        state = state.copyWith(status: AuthStatus.autenticado, nextStep: paso);
      }
      return ok;
    });
  }

  /* ───────────── Biometría ───────────── */

  Future<bool> activarBiometria() async {
    final ok = await _bio.autenticar(razon: 'Confirma tu identidad para activar el acceso rápido');
    if (!ok) return false;
    return _ejecutar(() async {
      await _repo.enrollBiometric();
      await _prefs.setBiometricEnabled(true);
      state = state.copyWith(biometriaActiva: true, mensaje: 'Acceso biométrico activado');
      return true;
    });
  }

  Future<void> desactivarBiometria() async {
    await _repo.disableBiometric();
    await _prefs.setBiometricEnabled(false);
    state = state.copyWith(biometriaActiva: false, mensaje: 'Acceso biométrico desactivado');
  }

  Future<bool> entrarConBiometria() async {
    if (!await _repo.biometricEnrolled) return false;
    final ok = await _bio.autenticar();
    if (!ok) return false;
    return _ejecutar(() async {
      final res = await _repo.loginWithBiometric();
      await _sesionIniciada(res.nextStep);
      return true;
    });
  }

  /* ───────────── Ciclo de vida de la sesión ───────────── */

  Future<void> refrescarUsuario() async {
    try {
      final user = await _repo.me();
      final paso = await _repo.nextStep();
      state = state.copyWith(user: user, nextStep: paso);
    } on ApiException catch (e) {
      debugPrint('[auth] no se pudo refrescar: ${e.code}');
    }
  }

  /// Bloquea la app tras inactividad (vuelve a pedir el PIN).
  void registrarActividad() => _ultimaActividad = DateTime.now();

  void evaluarBloqueoPorInactividad(Duration limite) {
    if (state.status != AuthStatus.autenticado) return;
    if (state.user?.hasPin != true) return;
    final ultima = _ultimaActividad;
    if (ultima != null && DateTime.now().difference(ultima) > limite) {
      state = state.copyWith(status: AuthStatus.bloqueado);
    }
  }

  void bloquear() {
    if (state.user?.hasPin == true) {
      state = state.copyWith(status: AuthStatus.bloqueado);
    }
  }

  /// Llamado por el interceptor cuando el refresh token ya no sirve.
  void sesionExpirada() {
    state = state.copyWith(
      status: AuthStatus.invitado,
      limpiarUsuario: true,
      limpiarChallenge: true,
      error: 'Tu sesión expiró. Inicia sesión de nuevo.',
    );
  }

  Future<void> cerrarSesion({bool todosLosDispositivos = false}) async {
    await _repo.logout(allDevices: todosLosDispositivos);
    if (todosLosDispositivos) await _prefs.setBiometricEnabled(false);
    state = AuthState(
      status: AuthStatus.invitado,
      biometriaDisponible: state.biometriaDisponible,
      biometriaActiva: todosLosDispositivos ? false : state.biometriaActiva,
      mensaje: 'Cerraste sesión correctamente',
    );
  }

  void limpiarError() => state = state.copyWith(limpiarError: true);
  void limpiarMensaje() => state = state.copyWith(limpiarMensaje: true);
  void volverAlLogin() => state = state.copyWith(
        status: AuthStatus.invitado,
        limpiarChallenge: true,
        limpiarError: true,
      );

  /* ───────────── Infraestructura interna ───────────── */

  Future<void> _sesionIniciada(String? paso) async {
    AppUser? user;
    try {
      user = await _repo.me();
    } on ApiException catch (_) {
      user = state.user;
    }
    _ultimaActividad = DateTime.now();
    state = state.copyWith(
      status: AuthStatus.autenticado,
      user: user,
      nextStep: paso ?? 'home',
      limpiarChallenge: true,
      limpiarError: true,
    );
  }

  /// Envuelve una operación con `cargando` + traducción de errores.
  Future<bool> _ejecutar(Future<bool> Function() accion) async {
    state = state.copyWith(cargando: true, limpiarError: true, limpiarMensaje: true);
    try {
      final ok = await accion();
      state = state.copyWith(cargando: false);
      return ok;
    } on ApiException catch (e) {
      state = state.copyWith(cargando: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(cargando: false, error: 'Ocurrió un error inesperado.');
      return false;
    }
  }
}

/// Carga asíncrona de `SharedPreferences` para `main()`.
final preferencesLoaderProvider = FutureProvider<AppPreferences>((ref) async {
  return AppPreferences(await SharedPreferences.getInstance());
});
