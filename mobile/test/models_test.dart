import 'package:flutter_test/flutter_test.dart';
import 'package:remesas_app/features/auth/data/models/auth_models.dart';
import 'package:remesas_app/features/auth/data/models/user_model.dart';

void main() {
  group('AppUser', () {
    final json = {
      'id': 'u-1',
      'firstName': 'María',
      'lastName': 'González',
      'email': 'maria@remesas.app',
      'phone': '+584121234567',
      'countryCode': 'VE',
      'status': 'active',
      'emailVerified': true,
      'phoneVerified': true,
      'hasPin': true,
      'kycLevel': 1,
      'kycStatus': 'approved',
    };

    test('se deserializa correctamente', () {
      final user = AppUser.fromJson(json);
      expect(user.fullName, 'María González');
      expect(user.initials, 'MG');
      expect(user.kycApproved, isTrue);
    });

    test('tolera campos ausentes', () {
      final user = AppUser.fromJson({'id': 'u-2'});
      expect(user.kycLevel, 0);
      expect(user.kycStatus, 'not_started');
      expect(user.hasPin, isFalse);
    });
  });

  group('OtpChallenge', () {
    test('expone el destino enmascarado', () {
      final challenge = OtpChallenge.fromJson({
        'challengeId': 'c-1',
        'purpose': 'register',
        'expiresInSeconds': 300,
        'maskedPhone': '+58 *** *** 4567',
      });
      expect(challenge.destino, '+58 *** *** 4567');
      expect(challenge.devCode, isNull);
    });
  });

  group('KycStatus', () {
    test('mapea límites por nivel', () {
      final estado = KycStatus.fromJson({
        'kycStatus': 'approved',
        'kycLevel': 1,
        'limits': {'perTransaction': 1000, 'daily': 2000, 'monthly': 10000, 'label': 'Verificado'},
        'submission': {'status': 'approved', 'submittedAt': '2026-01-01T00:00:00Z'},
      });
      expect(estado.aprobado, isTrue);
      expect(estado.perTransaction, 1000);
      expect(estado.limitLabel, 'Verificado');
    });

    test('valores por defecto sin verificación', () {
      final estado = KycStatus.fromJson({});
      expect(estado.status, 'not_started');
      expect(estado.perTransaction, 0);
    });
  });
}
