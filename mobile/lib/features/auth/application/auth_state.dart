import '../data/models/auth_models.dart';
import '../data/models/user_model.dart';

/// Situación de la sesión dentro del flujo de inicio.
enum AuthStatus {
  /// Arrancando: aún no sabemos si hay sesión.
  desconocido,

  /// Sin sesión: onboarding / login / registro.
  invitado,

  /// Credenciales correctas pero falta el segundo factor.
  esperandoOtp,

  /// Sesión válida (el `nextStep` dice si falta PIN o KYC).
  autenticado,

  /// Sesión válida pero la app está bloqueada por inactividad: pedir PIN.
  bloqueado,
}

/// Estado inmutable que consume toda la UI.
class AuthState {
  const AuthState({
    this.status = AuthStatus.desconocido,
    this.user,
    this.challenge,
    this.nextStep = 'home',
    this.cargando = false,
    this.error,
    this.mensaje,
    this.biometriaDisponible = false,
    this.biometriaActiva = false,
    this.resetToken,
  });

  final AuthStatus status;
  final AppUser? user;
  final OtpChallenge? challenge;

  /// `verify_otp` · `pin_setup` · `kyc` · `kyc_pending` · `home`
  final String nextStep;

  final bool cargando;
  final String? error;
  final String? mensaje;

  /// El hardware soporta huella/rostro.
  final bool biometriaDisponible;

  /// El usuario ya activó la biometría en este dispositivo.
  final bool biometriaActiva;

  /// Token efímero para la pantalla de nueva contraseña.
  final String? resetToken;

  bool get autenticado =>
      status == AuthStatus.autenticado || status == AuthStatus.bloqueado;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    OtpChallenge? challenge,
    String? nextStep,
    bool? cargando,
    String? error,
    String? mensaje,
    bool? biometriaDisponible,
    bool? biometriaActiva,
    String? resetToken,
    bool limpiarError = false,
    bool limpiarMensaje = false,
    bool limpiarChallenge = false,
    bool limpiarUsuario = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: limpiarUsuario ? null : (user ?? this.user),
      challenge: limpiarChallenge ? null : (challenge ?? this.challenge),
      nextStep: nextStep ?? this.nextStep,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
      mensaje: limpiarMensaje ? null : (mensaje ?? this.mensaje),
      biometriaDisponible: biometriaDisponible ?? this.biometriaDisponible,
      biometriaActiva: biometriaActiva ?? this.biometriaActiva,
      resetToken: resetToken ?? this.resetToken,
    );
  }
}
