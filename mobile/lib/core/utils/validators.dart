/// Validadores de formulario. Mantienen las mismas reglas que el backend
/// para que el usuario nunca vea un error "sorpresa" del servidor.
abstract final class Validators {
  static final _email = RegExp(r'^[\w.!#$%&*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$');
  static final _soloLetras = RegExp(r"^[\p{L}\s'’-]+$", unicode: true);

  static String? requerido(String? value, {String campo = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) return '$campo es obligatorio';
    return null;
  }

  static String? nombre(String? value, {String campo = 'El nombre'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$campo es obligatorio';
    if (v.length < 2) return '$campo es muy corto';
    if (v.length > 60) return '$campo es muy largo';
    if (!_soloLetras.hasMatch(v)) return '$campo solo admite letras';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El correo es obligatorio';
    if (!_email.hasMatch(v)) return 'Correo electrónico inválido';
    return null;
  }

  /// [phone] llega sin prefijo; [dialCode] lo aporta el selector de país.
  static String? telefono(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'El teléfono es obligatorio';
    if (digits.length < 7) return 'Número demasiado corto';
    if (digits.length > 14) return 'Número demasiado largo';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'La contraseña es obligatoria';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (fuerzaPassword(v) < 3) {
      return 'Añade mayúsculas, números o símbolos';
    }
    return null;
  }

  static String? confirmacion(String? value, String original) {
    if (value != original) return 'Las contraseñas no coinciden';
    return null;
  }

  /// Puntaje 0-4 idéntico al del backend (`utils/password.js`).
  static int fuerzaPassword(String pwd) {
    var score = 0;
    if (pwd.length >= 8) score++;
    if (pwd.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(pwd) && RegExp(r'[A-Z]').hasMatch(pwd)) score++;
    if (RegExp(r'\d').hasMatch(pwd)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) score++;
    return score > 4 ? 4 : score;
  }

  static String etiquetaFuerza(int score) => switch (score) {
        0 || 1 => 'Muy débil',
        2 => 'Débil',
        3 => 'Buena',
        _ => 'Excelente',
      };

  static String? documento(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'El número de documento es obligatorio';
    if (v.length < 5) return 'Número de documento muy corto';
    return null;
  }
}
