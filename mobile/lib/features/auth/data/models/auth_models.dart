/// Reto de verificación en dos pasos devuelto por el backend.
class OtpChallenge {
  const OtpChallenge({
    required this.challengeId,
    required this.purpose,
    required this.expiresInSeconds,
    this.maskedPhone,
    this.maskedEmail,
    this.devCode,
  });

  final String challengeId;
  /// `register` · `login` · `password_reset`
  final String purpose;
  final int expiresInSeconds;
  final String? maskedPhone;
  final String? maskedEmail;

  /// Solo en desarrollo: el backend devuelve el código para poder probar
  /// el flujo sin un SMS real. En producción llega `null`.
  final String? devCode;

  String get destino => maskedPhone ?? maskedEmail ?? 'tu dispositivo';

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        challengeId: json['challengeId'] as String,
        purpose: json['purpose'] as String? ?? 'login',
        expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 300,
        maskedPhone: json['maskedPhone'] as String?,
        maskedEmail: json['maskedEmail'] as String?,
        devCode: json['devCode'] as String?,
      );
}

/// Par de tokens de la sesión.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 900,
      );
}

/// Resultado de un intento de autenticación: o pide OTP, o entrega sesión.
class AuthResult {
  const AuthResult({this.challenge, this.tokens, this.user, this.nextStep});

  final OtpChallenge? challenge;
  final AuthTokens? tokens;
  final Map<String, dynamic>? user;
  final String? nextStep;

  bool get requiresOtp => challenge != null;
}

/// Estado de la verificación de identidad.
class KycStatus {
  const KycStatus({
    required this.status,
    required this.level,
    required this.perTransaction,
    required this.daily,
    required this.monthly,
    required this.limitLabel,
    this.rejectionReason,
    this.submittedAt,
  });

  final String status; // not_started · in_review · approved · rejected
  final int level;
  final num perTransaction;
  final num daily;
  final num monthly;
  final String limitLabel;
  final String? rejectionReason;
  final String? submittedAt;

  bool get aprobado => status == 'approved';
  bool get enRevision => status == 'in_review';

  factory KycStatus.fromJson(Map<String, dynamic> json) {
    final limits = (json['limits'] as Map?)?.cast<String, dynamic>() ?? const {};
    final submission = (json['submission'] as Map?)?.cast<String, dynamic>();
    return KycStatus(
      status: json['kycStatus'] as String? ?? 'not_started',
      level: (json['kycLevel'] as num?)?.toInt() ?? 0,
      perTransaction: (limits['perTransaction'] as num?) ?? 0,
      daily: (limits['daily'] as num?) ?? 0,
      monthly: (limits['monthly'] as num?) ?? 0,
      limitLabel: limits['label'] as String? ?? 'Sin verificar',
      rejectionReason: submission?['rejectionReason'] as String?,
      submittedAt: submission?['submittedAt'] as String?,
    );
  }
}
