/// Usuario autenticado tal como lo expone `GET /auth/me`.
class AppUser {
  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.countryCode,
    required this.status,
    required this.emailVerified,
    required this.phoneVerified,
    required this.hasPin,
    required this.kycLevel,
    required this.kycStatus,
    this.lastLoginAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String countryCode;
  final String status;
  final bool emailVerified;
  final bool phoneVerified;
  final bool hasPin;
  final int kycLevel;
  final String kycStatus;
  final String? lastLoginAt;

  String get fullName => '$firstName $lastName';
  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    return (a + b).toUpperCase();
  }

  bool get kycApproved => kycStatus == 'approved';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        countryCode: json['countryCode'] as String? ?? 'US',
        status: json['status'] as String? ?? 'pending_verification',
        emailVerified: json['emailVerified'] as bool? ?? false,
        phoneVerified: json['phoneVerified'] as bool? ?? false,
        hasPin: json['hasPin'] as bool? ?? false,
        kycLevel: (json['kycLevel'] as num?)?.toInt() ?? 0,
        kycStatus: json['kycStatus'] as String? ?? 'not_started',
        lastLoginAt: json['lastLoginAt'] as String?,
      );
}
