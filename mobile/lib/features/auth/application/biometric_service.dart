import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Envoltorio sobre `local_auth` que nunca lanza excepciones a la UI
/// y que degrada con elegancia en plataformas sin soporte (web).
class BiometricService {
  BiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// ¿El dispositivo tiene sensor y credenciales configuradas?
  Future<bool> get disponible async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Nombre comercial para la UI: "Face ID", "huella digital"…
  Future<String> get etiqueta async {
    if (kIsWeb) return 'Biometría';
    try {
      final tipos = await _auth.getAvailableBiometrics();
      if (tipos.contains(BiometricType.face)) return 'Face ID';
      if (tipos.contains(BiometricType.fingerprint)) return 'Huella digital';
      if (tipos.contains(BiometricType.iris)) return 'Iris';
      return 'Biometría';
    } on PlatformException {
      return 'Biometría';
    }
  }

  /// Lanza el prompt del sistema. Devuelve `false` si el usuario cancela.
  Future<bool> autenticar({
    String razon = 'Confirma tu identidad para entrar a tu cuenta',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: razon,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on PlatformException catch (e) {
      debugPrint('[biometría] no disponible: ${e.code}');
      return false;
    }
  }
}
