import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../mock/admin_mock_data.dart';
import '../models/admin_models.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';
import '../remote/api_mappers.dart';

abstract interface class AdminRepository {
  Future<AdminDashboardData> fetchDashboard();

  Future<void> updateUserStatus(String id, AdminUserStatus status);

  Future<void> reviewApproval(String id, bool approved);
}

class DemoAdminRepository implements AdminRepository {
  final List<AdminUser> _users = [...AdminMockData.users];
  final List<AdminApproval> _approvals = AdminMockData.approvals();
  AdminStats _stats = AdminMockData.stats;

  @override
  Future<AdminDashboardData> fetchDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    return AdminDashboardData(
      stats: _stats,
      users: [..._users],
      approvals: [..._approvals],
    );
  }

  @override
  Future<void> updateUserStatus(String id, AdminUserStatus status) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final index = _users.indexWhere((user) => user.id == id);
    if (index == -1) {
      throw const ValidationException('Usuario no encontrado.');
    }
    _users[index] = _users[index].copyWith(status: status);
  }

  @override
  Future<void> reviewApproval(String id, bool approved) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final index = _approvals.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw const ValidationException('Solicitud no encontrada.');
    }
    _approvals[index] = _approvals[index].copyWith(
      status: approved
          ? AdminApprovalStatus.approved
          : AdminApprovalStatus.rejected,
    );
    final pending = _approvals
        .where((approval) => approval.status == AdminApprovalStatus.pending)
        .length;
    _stats = _stats.copyWith(pendingApprovals: pending);
  }
}

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository(this._api, this._store);

  final ApiClient _api;
  final SessionStore _store;

  String _token() {
    final token = _store.loadToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('La sesión expiró. Inicia sesión de nuevo.');
    }
    return token;
  }

  @override
  Future<AdminDashboardData> fetchDashboard() async {
    try {
      final payload = await _api.get(
        ApiEndpoints.adminSummary,
        token: _token(),
      );
      return ApiMappers.adminDashboard(payload);
    } on AppException {
      final payload = await _api.get(ApiEndpoints.adminUsers, token: _token());
      final raw = payload['usuarios'] ?? payload['data'];
      return ApiMappers.adminDashboard(
        raw is List ? {'usuarios': raw} : payload,
      );
    }
  }

  @override
  Future<void> updateUserStatus(String id, AdminUserStatus status) async {
    await _api.patch(
      ApiEndpoints.adminUserStatus(id),
      token: _token(),
      body: {
        'estado': switch (status) {
          AdminUserStatus.active => 'Activo',
          AdminUserStatus.pending => 'Pendiente',
          AdminUserStatus.suspended => 'Suspendido',
        },
      },
    );
  }

  @override
  Future<void> reviewApproval(String id, bool approved) async {
    await _api.patch(
      ApiEndpoints.adminApproval(id),
      token: _token(),
      body: {'estado': approved ? 'Aprobada' : 'Rechazada'},
    );
  }
}
