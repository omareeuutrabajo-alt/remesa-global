import 'package:flutter_test/flutter_test.dart';
import 'package:remesas_app/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('acepta correos válidos', () {
      expect(Validators.email('maria.gonzalez@remesas.app'), isNull);
      expect(Validators.email('  user+tag@dominio.co  '), isNull);
    });

    test('rechaza correos inválidos', () {
      expect(Validators.email(''), 'El correo es obligatorio');
      expect(Validators.email('sin-arroba.com'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('exige longitud mínima', () {
      expect(Validators.password('Ab1\$'), 'Mínimo 8 caracteres');
    });

    test('rechaza contraseñas sin complejidad', () {
      expect(Validators.password('solominusculas'), isNotNull);
    });

    test('acepta una contraseña fuerte', () {
      expect(Validators.password('Remesas2026\$Seg'), isNull);
    });
  });

  group('Validators.fuerzaPassword', () {
    test('puntúa igual que el backend (0-4)', () {
      expect(Validators.fuerzaPassword('abc'), 0);
      expect(Validators.fuerzaPassword('abcdefgh'), 1);
      expect(Validators.fuerzaPassword('Abcdefgh1'), 3);
      expect(Validators.fuerzaPassword('Abcdefghijk1\$'), 4);
    });

    test('nunca supera 4', () {
      expect(Validators.fuerzaPassword('SuperLarga2026\$\$\$aA'), lessThanOrEqualTo(4));
    });
  });

  group('Validators.telefono', () {
    test('valida longitud del número nacional', () {
      expect(Validators.telefono('4121234567'), isNull);
      expect(Validators.telefono('123'), isNotNull);
      expect(Validators.telefono(''), 'El teléfono es obligatorio');
    });
  });

  group('Validators.nombre', () {
    test('acepta tildes y apóstrofos', () {
      expect(Validators.nombre('José'), isNull);
      expect(Validators.nombre("D'Angelo"), isNull);
    });

    test('rechaza números y símbolos', () {
      expect(Validators.nombre('Juan123'), isNotNull);
    });
  });

  group('Validators.confirmacion', () {
    test('detecta contraseñas distintas', () {
      expect(Validators.confirmacion('abc', 'abd'), 'Las contraseñas no coinciden');
      expect(Validators.confirmacion('abc', 'abc'), isNull);
    });
  });
}
