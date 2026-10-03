import 'package:flutter_test/flutter_test.dart';
import 'package:remesas_app/features/auth/application/auth_state.dart';

void main() {
  group('AuthState.copyWith', () {
    test('conserva los valores no indicados', () {
      const inicial = AuthState(status: AuthStatus.autenticado, nextStep: 'home');
      final copia = inicial.copyWith(cargando: true);
      expect(copia.status, AuthStatus.autenticado);
      expect(copia.nextStep, 'home');
      expect(copia.cargando, isTrue);
    });

    test('las banderas de limpieza borran campos', () {
      const conError = AuthState(error: 'fallo');
      expect(conError.copyWith(limpiarError: true).error, isNull);
    });

    test('autenticado cubre también el estado bloqueado', () {
      expect(const AuthState(status: AuthStatus.bloqueado).autenticado, isTrue);
      expect(const AuthState(status: AuthStatus.invitado).autenticado, isFalse);
    });
  });
}
