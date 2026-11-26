import 'package:material_ui/material_ui.dart';

enum UserRole {
  client('Cliente', Icons.person_outline_rounded),
  owner('Propietario', Icons.car_rental_rounded),
  driver('Conductor', Icons.badge_outlined),
  admin('Administrador', Icons.admin_panel_settings_outlined);

  const UserRole(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum LicenseStatus {
  notSubmitted('Sin verificar', Color(0xFF525252), Icons.shield_outlined),
  pendingReview('En revisión', Color(0xFFB45309), Icons.hourglass_top_rounded),
  approved('Verificada', Color(0xFF0E8A75), Icons.verified_user_rounded),
  expired('Vencida', Color(0xFFB45309), Icons.event_busy_outlined),
  suspended('Suspendida', Color(0xFFBA1A1A), Icons.block_outlined),
  rejected('Rechazada', Color(0xFFBA1A1A), Icons.error_outline_rounded);

  const LicenseStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static LicenseStatus fromApi(Object? value) {
    return switch ('$value'.toLowerCase()) {
      'vigente' || 'aprobada' || 'approved' => approved,
      'vencida' || 'expired' => expired,
      'suspendida' || 'suspended' => suspended,
      'en_revision' || 'pendiente' || 'pending' => pendingReview,
      'rechazada' || 'rejected' => rejected,
      _ => notSubmitted,
    };
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.city,
    this.document = '',
    this.avatarAsset,
    this.avatarUrl,
    this.roles = const {UserRole.client},
    this.licenseStatus = LicenseStatus.notSubmitted,
    this.isEmailVerified = true,
    this.isPhoneVerified = true,
    this.memberSince,
    this.rating = 4.9,
    this.tripCount = 0,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String city;
  final String document;
  final String? avatarAsset;
  final String? avatarUrl;
  final Set<UserRole> roles;
  final LicenseStatus licenseStatus;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final DateTime? memberSince;
  final double rating;
  final int tripCount;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.isEmpty ? 'C' : firstName[0];
    final last = lastName.isEmpty ? '' : lastName[0];
    return '$first$last'.toUpperCase();
  }

  bool get isOwner => roles.contains(UserRole.owner);

  bool get isDriver => roles.contains(UserRole.driver);

  bool get isAdmin => roles.contains(UserRole.admin);

  bool get canBook => licenseStatus == LicenseStatus.approved;

  bool get hasAvatar => avatarAsset != null || avatarUrl != null;

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? city,
    String? document,
    String? avatarAsset,
    String? avatarUrl,
    Set<UserRole>? roles,
    LicenseStatus? licenseStatus,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    DateTime? memberSince,
    double? rating,
    int? tripCount,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      document: document ?? this.document,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roles: roles ?? this.roles,
      licenseStatus: licenseStatus ?? this.licenseStatus,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      memberSince: memberSince ?? this.memberSince,
      rating: rating ?? this.rating,
      tripCount: tripCount ?? this.tripCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'city': city,
    'document': document,
    'avatarAsset': avatarAsset,
    'roles': roles.map((role) => role.name).toList(),
    'licenseStatus': licenseStatus.name,
    'isEmailVerified': isEmailVerified,
    'isPhoneVerified': isPhoneVerified,
    'memberSince': memberSince?.toIso8601String(),
    'rating': rating,
    'tripCount': tripCount,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawRoles = (json['roles'] as List<dynamic>?) ?? const ['client'];
    final roles = rawRoles.map((role) {
      final name = '$role'.toLowerCase();
      return UserRole.values.firstWhere(
        (candidate) => candidate.name == name,
        orElse: () => UserRole.client,
      );
    }).toSet();
    return UserProfile(
      id: '${json['id'] ?? 'demo-user'}',
      firstName: '${json['firstName'] ?? json['nombre'] ?? 'Alex'}',
      lastName: '${json['lastName'] ?? json['apellido'] ?? 'Rivera'}',
      email: '${json['email'] ?? ''}',
      phone: '${json['phone'] ?? json['telefono'] ?? ''}',
      city: '${json['city'] ?? json['ciudad'] ?? 'Cartagena'}',
      document: '${json['document'] ?? json['documento'] ?? ''}',
      avatarAsset: json['avatarAsset'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      // Una sesión de API puede tener cero roles: no otorgar "cliente" por
      // defecto al recargarla desde SharedPreferences.
      roles: roles,
      licenseStatus: LicenseStatus.fromApi(
        json['licenseStatus'] ?? json['license'],
      ),
      isEmailVerified: json['isEmailVerified'] as bool? ?? true,
      isPhoneVerified: json['isPhoneVerified'] as bool? ?? true,
      memberSince: DateTime.tryParse('${json['memberSince'] ?? ''}'),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      tripCount: (json['tripCount'] as num?)?.toInt() ?? 0,
    );
  }
}
