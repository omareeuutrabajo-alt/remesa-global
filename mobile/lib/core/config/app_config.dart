import 'package:flutter/foundation.dart';

/// Entornos soportados por la app.
enum Flavor { dev, staging, prod }

/// Configuración central: todo lo que cambia entre entornos vive aquí.
class AppConfig {
  const AppConfig._();

  static const Flavor flavor = kReleaseMode ? Flavor.prod : Flavor.dev;

  static const String appName = 'Remesa Global';
  static const String appTagline = 'Envía dinero a casa en minutos';

  /// URL base de la API.
  ///
  /// • Web      → mismo origen (el backend sirve el build web).
  /// • Android  → 10.0.2.2 es el host desde el emulador.
  /// • iOS/desk → localhost.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_URL');
    if (override.isNotEmpty) return override;
    // Mismo origen que el servidor que sirve el build (evita CORS).
    if (kIsWeb) return '${Uri.base.origin}/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://localhost:4000/api/v1';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Tiempo de inactividad tras el cual se pide el PIN de nuevo.
  static const Duration lockTimeout = Duration(minutes: 3);

  static const int otpLength = 6;
  static const int pinLength = 6;
  static const int otpResendSeconds = 60;

  static const String supportEmail = 'soporte@remesaglobal.app';
  static const String termsUrl = 'https://remesaglobal.app/terminos';
  static const String privacyUrl = 'https://remesaglobal.app/privacidad';
}
