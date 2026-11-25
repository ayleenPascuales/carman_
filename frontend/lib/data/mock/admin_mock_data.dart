import '../../core/constants/app_assets.dart';
import '../models/admin_models.dart';
import '../models/user_profile.dart';

abstract final class AdminMockData {
  static final users = <AdminUser>[
    AdminUser(
      id: 'admin-user-1',
      name: 'Alex Rivera',
      email: 'alex.rivera@carman.es',
      phone: '+57 300 123 4567',
      city: 'Cartagena',
      roles: const {
        UserRole.client,
        UserRole.owner,
        UserRole.driver,
        UserRole.admin,
      },
      status: AdminUserStatus.active,
      joinedAt: DateTime(2024, 3, 12),
      trips: 14,
      avatarAsset: AppAssets.avatarUser,
    ),
    AdminUser(
      id: 'admin-user-2',
      name: 'María Gómez',
      email: 'maria.gomez@example.com',
      phone: '+57 301 224 9011',
      city: 'Medellín',
      roles: const {UserRole.client},
      status: AdminUserStatus.active,
      joinedAt: DateTime(2026, 9, 18),
      trips: 3,
    ),
    AdminUser(
      id: 'admin-user-3',
      name: 'Carlos Mendoza',
      email: 'carlos.mendoza@example.com',
      phone: '+57 315 800 4420',
      city: 'Cartagena',
      roles: const {UserRole.driver},
      status: AdminUserStatus.active,
      joinedAt: DateTime(2025, 1, 30),
      trips: 128,
      verified: true,
    ),
    AdminUser(
      id: 'admin-user-4',
      name: 'Laura Pérez',
      email: 'laura.perez@example.com',
      phone: '+57 318 440 1120',
      city: 'Bogotá',
      roles: const {UserRole.owner},
      status: AdminUserStatus.pending,
      joinedAt: DateTime(2026, 11, 15),
      trips: 0,
      verified: false,
    ),
    AdminUser(
      id: 'admin-user-5',
      name: 'Andrés Prieto',
      email: 'andres.prieto@example.com',
      phone: '+57 300 990 4412',
      city: 'Cartagena',
      roles: const {UserRole.client},
      status: AdminUserStatus.suspended,
      joinedAt: DateTime(2025, 7, 4),
      trips: 9,
      verified: true,
    ),
    AdminUser(
      id: 'admin-user-6',
      name: 'Sofía López',
      email: 'sofia.lopez@example.com',
      phone: '+57 312 667 3810',
      city: 'Bogotá',
      roles: const {UserRole.owner, UserRole.driver},
      status: AdminUserStatus.active,
      joinedAt: DateTime(2024, 10, 8),
      trips: 42,
      verified: true,
    ),
    AdminUser(
      id: 'admin-user-7',
      name: 'Daniel Mejía',
      email: 'daniel.mejia@example.com',
      phone: '+57 321 404 7781',
      city: 'Medellín',
      roles: const {UserRole.client},
      status: AdminUserStatus.active,
      joinedAt: DateTime(2026, 2, 21),
      trips: 6,
    ),
  ];

  static List<AdminApproval> approvals() {
    final now = DateTime.now();
    return [
      AdminApproval(
        id: 'approval-1',
        type: AdminApprovalType.license,
        subjectName: 'María Gómez',
        subjectEmail: 'maria.gomez@example.com',
        title: 'Licencia de conducir',
        detail: 'Categoría B · vence 20/08/2030',
        submittedAt: now.subtract(const Duration(minutes: 12)),
      ),
      AdminApproval(
        id: 'approval-2',
        type: AdminApprovalType.vehicle,
        subjectName: 'Laura Pérez',
        subjectEmail: 'laura.perez@example.com',
        title: 'BMW iX xDrive50 2024',
        detail: 'Placa BMW-1X50 · documentos completos',
        submittedAt: now.subtract(const Duration(minutes: 38)),
      ),
      AdminApproval(
        id: 'approval-3',
        type: AdminApprovalType.license,
        subjectName: 'Carlos Mendoza',
        subjectEmail: 'carlos.mendoza@example.com',
        title: 'Licencia de conducir',
        detail: 'Categoría C1 · documento actualizado',
        submittedAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  static const stats = AdminStats(
    totalUsers: 1248,
    activeDrivers: 86,
    activeVehicles: 312,
    pendingApprovals: 3,
    reservationsToday: 47,
    revenueMonth: 12480,
    growth: 12.8,
  );
}
