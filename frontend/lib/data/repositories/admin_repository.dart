import '../../core/errors/app_exception.dart';
import '../local/session_store.dart';
import '../mock/admin_mock_data.dart';
import '../models/admin_models.dart';
import '../remote/api_client.dart';
import '../remote/api_endpoints.dart';
import '../remote/api_mappers.dart';

abstract interface class AdminRepository {
  Future<AdminDashboardData> fetchDashboard({
    String search = '',
    String? role,
    String? status,
    String revisionStatus = 'Pendiente',
  });

  Future<void> updateUserStatus(String id, AdminUserStatus status);

  Future<void> reviewApproval(String id, bool approved, {String? reason});
}

class DemoAdminRepository implements AdminRepository {
  final List<AdminUser> _users = [...AdminMockData.users];
  final List<AdminApproval> _approvals = AdminMockData.approvals();
  AdminStats _stats = AdminMockData.stats;

  @override
  Future<AdminDashboardData> fetchDashboard({
    String search = '',
    String? role,
    String? status,
    String revisionStatus = 'Pendiente',
  }) async {
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
  Future<void> reviewApproval(
    String id,
    bool approved, {
    String? reason,
  }) async {
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

  String _id(String value) {
    final id = int.tryParse(value);
    if (id == null || id < 1) {
      throw const ValidationException('Identificador inválido.');
    }
    return '$id';
  }

  Map<String, dynamic> _list(Map<String, dynamic> response, String key) {
    if (response[key] is! List ||
        response['pagina'] is! int ||
        response['hayMas'] is! bool) {
      throw const AppException(
        'La lista administrativa no es válida.',
        code: 'invalid_admin_list',
      );
    }
    return response;
  }

  Future<Map<String, dynamic>> _users({
    int page = 1,
    String search = '',
    String? role,
    String? status,
  }) async {
    if (page < 1 || page > 9999 || search.length > 80) {
      throw const ValidationException('El filtro o la página no son válidos.');
    }
    final query = <String, String>{'pagina': '$page'};
    if (search.trim().isNotEmpty) query['buscar'] = search.trim();
    if (role != null) query['rol'] = role;
    if (status != null) query['estado'] = status;
    return _list(
      await _api.get(ApiEndpoints.adminUsers, token: _token(), query: query),
      'usuarios',
    );
  }

  Future<Map<String, dynamic>> _revisions({
    int page = 1,
    String status = 'Pendiente',
  }) async {
    if (page < 1 ||
        page > 9999 ||
        !['Pendiente', 'Aprobada'].contains(status)) {
      throw const ValidationException('Filtro de revisiones inválido.');
    }
    return _list(
      await _api.get(
        ApiEndpoints.adminApprovals,
        token: _token(),
        query: {'pagina': '$page', 'estado': status},
      ),
      'solicitudes',
    );
  }

  @override
  Future<AdminDashboardData> fetchDashboard({
    String search = '',
    String? role,
    String? status,
    String revisionStatus = 'Pendiente',
  }) async {
    final summary = await _api.get(ApiEndpoints.adminSummary, token: _token());
    if (summary['usuarios'] is! num ||
        summary['pendientes'] is! num ||
        summary['conductores'] is! num ||
        summary['vehiculos'] is! num ||
        summary['reservasHoy'] is! num) {
      throw const AppException('El resumen administrativo no es válido.');
    }
    final users = await _users(search: search, role: role, status: status);
    final reviews = await _revisions(status: revisionStatus);
    return ApiMappers.adminDashboard({
      'estadisticas': summary,
      'usuarios': users['usuarios'],
      'aprobaciones': reviews['solicitudes'],
      'paginaUsuarios': users['pagina'],
      'masUsuarios': users['hayMas'],
      'paginaRevisiones': reviews['pagina'],
      'masRevisiones': reviews['hayMas'],
    });
  }

  Future<AdminDashboardData> fetchUsers({
    int page = 1,
    String search = '',
    String? role,
    String? status,
  }) async {
    final raw = await _users(
      page: page,
      search: search,
      role: role,
      status: status,
    );
    return ApiMappers.adminDashboard({
      'estadisticas': <String, dynamic>{},
      'usuarios': raw['usuarios'],
      'aprobaciones': <dynamic>[],
      'paginaUsuarios': raw['pagina'],
      'masUsuarios': raw['hayMas'],
    });
  }

  Future<AdminDashboardData> fetchRevisions({
    int page = 1,
    String status = 'Pendiente',
  }) async {
    final raw = await _revisions(page: page, status: status);
    return ApiMappers.adminDashboard({
      'estadisticas': <String, dynamic>{},
      'usuarios': <dynamic>[],
      'aprobaciones': raw['solicitudes'],
      'paginaRevisiones': raw['pagina'],
      'masRevisiones': raw['hayMas'],
    });
  }

  Future<Map<String, dynamic>> fetchUser(String id) =>
      _api.get(ApiEndpoints.adminUser(_id(id)), token: _token());

  Future<Map<String, dynamic>> fetchRevision(String id) =>
      _api.get(ApiEndpoints.adminApproval(_id(id)), token: _token());

  Future<void> finalizeReview(String id, Map<String, dynamic> report) async {
    await _api.patch(
      '${ApiEndpoints.adminApproval(_id(id))}/finalizar',
      token: _token(),
      body: report,
    );
  }

  @override
  Future<void> updateUserStatus(String id, AdminUserStatus status) async {
    if (status != AdminUserStatus.active &&
        status != AdminUserStatus.suspended) {
      throw const ValidationException('Esta transición no está disponible.');
    }
    await _api.patch(
      ApiEndpoints.adminUserStatus(_id(id), status == AdminUserStatus.active),
      token: _token(),
    );
  }

  @override
  Future<void> reviewApproval(
    String id,
    bool approved, {
    String? reason,
  }) async {
    if (!approved && (reason?.trim().isEmpty ?? true)) {
      throw const ValidationException('Indica el motivo del rechazo.');
    }
    await _api.patch(
      '${ApiEndpoints.adminApproval(_id(id))}/${approved ? 'aceptar' : 'rechazar'}',
      token: _token(),
      body: approved ? null : {'motivoRechazo': reason!.trim()},
    );
  }
}
