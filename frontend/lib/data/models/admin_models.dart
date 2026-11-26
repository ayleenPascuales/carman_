import 'package:material_ui/material_ui.dart';

import 'user_profile.dart';

enum AdminUserStatus {
  active('Activo', Color(0xFF0E8A75)),
  pending('Pendiente', Color(0xFFB45309)),
  suspended('Suspendido', Color(0xFFBA1A1A)),
  inactive('Inactivo', Color(0xFF525252)),
  unknown('Estado no disponible', Color(0xFF525252));

  const AdminUserStatus(this.label, this.color);

  final String label;
  final Color color;

  static AdminUserStatus fromApi(Object? value) {
    final normalized = '${value ?? ''}'.toLowerCase();
    if (normalized.contains('suspend') || normalized.contains('bloque')) {
      return suspended;
    }
    if (normalized.contains('pend') || normalized.contains('revision')) {
      return pending;
    }
    if (normalized == 'activo' || normalized == 'active') return active;
    if (normalized == 'inactivo' || normalized == 'inactive') return inactive;
    return unknown;
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.roles,
    required this.status,
    required this.joinedAt,
    required this.trips,
    this.verified = true,
    this.avatarAsset,
    this.isAdmin = false,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final Set<UserRole> roles;
  final AdminUserStatus status;
  final DateTime joinedAt;
  final int trips;
  final bool verified;
  final String? avatarAsset;
  final bool isAdmin;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get rolesLabel => roles.map((role) => role.label).join(' · ');

  UserRole get primaryRole {
    if (roles.contains(UserRole.admin)) return UserRole.admin;
    if (roles.contains(UserRole.owner)) return UserRole.owner;
    if (roles.contains(UserRole.driver)) return UserRole.driver;
    return UserRole.client;
  }

  AdminUser copyWith({AdminUserStatus? status}) {
    return AdminUser(
      id: id,
      name: name,
      email: email,
      phone: phone,
      city: city,
      roles: roles,
      status: status ?? this.status,
      joinedAt: joinedAt,
      trips: trips,
      verified: verified,
      avatarAsset: avatarAsset,
      isAdmin: isAdmin,
    );
  }
}

enum AdminApprovalType {
  license('Licencia', Icons.verified_user_outlined),
  vehicle('Vehículo', Icons.directions_car_outlined);

  const AdminApprovalType(this.label, this.icon);

  final String label;
  final IconData icon;

  static AdminApprovalType fromApi(Object? value) {
    return '${value ?? ''}'.toLowerCase().contains('vehic') ? vehicle : license;
  }
}

enum AdminApprovalStatus { pending, approved, rejected, finalized }

class AdminApproval {
  const AdminApproval({
    required this.id,
    required this.type,
    required this.subjectName,
    required this.subjectEmail,
    required this.title,
    required this.detail,
    this.submittedAt,
    this.status = AdminApprovalStatus.pending,
    this.avatarAsset,
  });

  final String id;
  final AdminApprovalType type;
  final String subjectName;
  final String subjectEmail;
  final String title;
  final String detail;
  final DateTime? submittedAt;
  final AdminApprovalStatus status;
  final String? avatarAsset;

  AdminApproval copyWith({AdminApprovalStatus? status}) {
    return AdminApproval(
      id: id,
      type: type,
      subjectName: subjectName,
      subjectEmail: subjectEmail,
      title: title,
      detail: detail,
      submittedAt: submittedAt,
      status: status ?? this.status,
      avatarAsset: avatarAsset,
    );
  }
}

class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.activeDrivers,
    required this.activeVehicles,
    required this.pendingApprovals,
    required this.reservationsToday,
    required this.revenueMonth,
    required this.growth,
  });

  final int totalUsers;
  final int activeDrivers;
  final int activeVehicles;
  final int pendingApprovals;
  final int reservationsToday;
  final double revenueMonth;
  final double growth;

  AdminStats copyWith({
    int? totalUsers,
    int? activeDrivers,
    int? activeVehicles,
    int? pendingApprovals,
    int? reservationsToday,
    double? revenueMonth,
    double? growth,
  }) {
    return AdminStats(
      totalUsers: totalUsers ?? this.totalUsers,
      activeDrivers: activeDrivers ?? this.activeDrivers,
      activeVehicles: activeVehicles ?? this.activeVehicles,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      reservationsToday: reservationsToday ?? this.reservationsToday,
      revenueMonth: revenueMonth ?? this.revenueMonth,
      growth: growth ?? this.growth,
    );
  }
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.stats,
    required this.users,
    required this.approvals,
    this.usersPage = 1,
    this.usersHasMore = false,
    this.revisionsPage = 1,
    this.revisionsHasMore = false,
  });

  final AdminStats stats;
  final List<AdminUser> users;
  final List<AdminApproval> approvals;
  final int usersPage;
  final bool usersHasMore;
  final int revisionsPage;
  final bool revisionsHasMore;

  AdminDashboardData copyWith({
    AdminStats? stats,
    List<AdminUser>? users,
    List<AdminApproval>? approvals,
    int? usersPage,
    bool? usersHasMore,
    int? revisionsPage,
    bool? revisionsHasMore,
  }) {
    return AdminDashboardData(
      stats: stats ?? this.stats,
      users: users ?? this.users,
      approvals: approvals ?? this.approvals,
      usersPage: usersPage ?? this.usersPage,
      usersHasMore: usersHasMore ?? this.usersHasMore,
      revisionsPage: revisionsPage ?? this.revisionsPage,
      revisionsHasMore: revisionsHasMore ?? this.revisionsHasMore,
    );
  }
}
