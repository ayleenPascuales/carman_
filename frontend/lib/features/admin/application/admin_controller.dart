import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../providers.dart';
import '../../auth/application/auth_controller.dart';

class AdminState {
  const AdminState({
    this.data,
    this.isLoading = true,
    this.error,
    this.actionId,
    this.search = '',
    this.role,
    this.status,
    this.revisionStatus = 'Pendiente',
    this.isLoadingMore = false,
  });

  final AdminDashboardData? data;
  final bool isLoading;
  final String? error;
  final String? actionId;
  final String search;
  final String? role;
  final String? status;
  final String revisionStatus;
  final bool isLoadingMore;

  int get pendingApprovals => (data?.approvals ?? const [])
      .where((item) => item.status == AdminApprovalStatus.pending)
      .length;

  AdminState copyWith({
    AdminDashboardData? data,
    bool? isLoading,
    String? error,
    String? actionId,
    bool clearError = false,
    bool clearAction = false,
    String? search,
    String? role,
    String? status,
    bool clearRole = false,
    bool clearStatus = false,
    String? revisionStatus,
    bool? isLoadingMore,
  }) {
    return AdminState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      actionId: clearAction ? null : (actionId ?? this.actionId),
      search: search ?? this.search,
      role: clearRole ? null : (role ?? this.role),
      status: clearStatus ? null : (status ?? this.status),
      revisionStatus: revisionStatus ?? this.revisionStatus,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class AdminController extends Notifier<AdminState> {
  int _requestVersion = 0;
  @override
  AdminState build() {
    final id = ref.watch(
      authControllerProvider.select((auth) => auth.user?.id),
    );
    if (id == null) return const AdminState(isLoading: false);
    Future.microtask(load);
    return const AdminState();
  }

  Future<void> load() async {
    final accountId = ref.read(authControllerProvider).user?.id;
    if (accountId == null) return;
    final version = ++_requestVersion;
    final previous = state;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ref
          .read(adminRepositoryProvider)
          .fetchDashboard(
            search: previous.search,
            role: previous.role,
            status: previous.status,
            revisionStatus: previous.revisionStatus,
          );
      if (!ref.mounted ||
          version != _requestVersion ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      state = AdminState(
        data: data,
        isLoading: false,
        search: previous.search,
        role: previous.role,
        status: previous.status,
        revisionStatus: previous.revisionStatus,
      );
    } on AppException catch (error) {
      if (!ref.mounted ||
          version != _requestVersion ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      state = AdminState(
        isLoading: false,
        error: error.message,
        search: previous.search,
        role: previous.role,
        status: previous.status,
        revisionStatus: previous.revisionStatus,
      );
    } catch (_) {
      if (!ref.mounted ||
          version != _requestVersion ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      state = AdminState(
        isLoading: false,
        error: 'No pudimos cargar la administración.',
        search: previous.search,
        role: previous.role,
        status: previous.status,
        revisionStatus: previous.revisionStatus,
      );
    }
  }

  Future<void> filterUsers({
    String? search,
    String? role,
    String? status,
  }) async {
    if (!AppConfig.useLiveApi) return;
    state = state.copyWith(
      search: search,
      role: role,
      status: status,
      clearRole: role == '',
      clearStatus: status == '',
    );
    await load();
  }

  Future<void> filterRevisions(String status) async {
    if (!AppConfig.useLiveApi || !['Pendiente', 'Aprobada'].contains(status)) {
      return;
    }
    state = state.copyWith(revisionStatus: status);
    await load();
  }

  Future<void> loadMore({required bool users}) async {
    final data = state.data;
    if (!AppConfig.useLiveApi ||
        data == null ||
        state.isLoading ||
        state.isLoadingMore ||
        state.actionId != null ||
        !(users ? data.usersHasMore : data.revisionsHasMore)) {
      return;
    }
    final accountId = ref.read(authControllerProvider).user?.id;
    final version = _requestVersion;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final repo = ref.read(adminRepositoryProvider) as ApiAdminRepository;
      final next = users
          ? await repo.fetchUsers(
              page: data.usersPage + 1,
              search: state.search,
              role: state.role,
              status: state.status,
            )
          : await repo.fetchRevisions(
              page: data.revisionsPage + 1,
              status: state.revisionStatus,
            );
      if (!ref.mounted ||
          version != _requestVersion ||
          ref.read(authControllerProvider).user?.id != accountId) {
        return;
      }
      if ((users
          ? next.usersPage != data.usersPage + 1
          : next.revisionsPage != data.revisionsPage + 1)) {
        throw const AppException('La página consultada no coincide.');
      }
      state = state.copyWith(
        isLoadingMore: false,
        data: users
            ? data.copyWith(
                users: [
                  ...data.users.where(
                    (u) => !next.users.any((other) => u.id == other.id),
                  ),
                  ...next.users,
                ],
                usersPage: next.usersPage,
                usersHasMore: next.usersHasMore,
              )
            : data.copyWith(
                approvals: [
                  ...data.approvals.where(
                    (r) => !next.approvals.any((other) => r.id == other.id),
                  ),
                  ...next.approvals,
                ],
                revisionsPage: next.revisionsPage,
                revisionsHasMore: next.revisionsHasMore,
              ),
      );
    } on AppException catch (error) {
      if (ref.mounted && version == _requestVersion) {
        state = state.copyWith(isLoadingMore: false, error: error.message);
      }
    } catch (_) {
      if (ref.mounted && version == _requestVersion) {
        state = state.copyWith(
          isLoadingMore: false,
          error: 'No se pudo cargar la página.',
        );
      }
    }
  }

  Future<bool> updateUserStatus(String id, AdminUserStatus status) async {
    final data = state.data;
    if ((!AppConfig.useLiveApi && data == null) ||
        state.actionId != null ||
        state.isLoading) {
      return false;
    }
    state = state.copyWith(actionId: id, clearError: true);
    try {
      if (AppConfig.useLiveApi) {
        final currentDetail = await (ref.read(
          adminRepositoryProvider,
        ) as ApiAdminRepository).fetchUser(id);
        if (!ref.mounted) return false;
        final roles = currentDetail['roles'];
        final current = AdminUserStatus.fromApi(currentDetail['estado']);
        if (roles is! Map<String, dynamic> ||
            roles['administrador'] == true ||
            !(current == AdminUserStatus.active &&
                    status == AdminUserStatus.suspended ||
                current == AdminUserStatus.suspended &&
                    status == AdminUserStatus.active)) {
          state = state.copyWith(
            error: 'La cuenta cambió o no admite esta acción. Actualiza su detalle.',
            clearAction: true,
          );
          return false;
        }
      }
      await ref.read(adminRepositoryProvider).updateUserStatus(id, status);
      if (AppConfig.useLiveApi) {
        final detail = await (ref.read(
          adminRepositoryProvider,
        ) as ApiAdminRepository).fetchUser(id);
        await load();
        if (!ref.mounted) return false;
        final confirmed =
            detail['estado'] == status.label && state.error == null;
        if (!confirmed) {
          state = state.copyWith(
            error: 'El cambio pudo guardarse; consulta el detalle antes de repetirlo.',
          );
        }
        return confirmed;
      }
      if (!ref.mounted) return true;
      final users = data!.users
          .map((user) => user.id == id ? user.copyWith(status: status) : user)
          .toList();
      state = state.copyWith(
        data: data.copyWith(users: users),
        clearAction: true,
      );
      return true;
    } on AppException catch (error) {
      if (!ref.mounted) return false;
      if (AppConfig.useLiveApi) await load();
      if (!ref.mounted) return false;
      state = state.copyWith(error: error.message, clearAction: true);
      return false;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          error: 'No se pudo confirmar la cuenta. Actualiza antes de repetir.',
          clearAction: true,
        );
      }
      return false;
    }
  }

  Future<bool> reviewApproval(
    String id,
    bool approved, {
    String? reason,
  }) async {
    final data = state.data;
    if ((!AppConfig.useLiveApi && data == null) ||
        state.actionId != null ||
        state.isLoading) {
      return false;
    }
    state = state.copyWith(actionId: id, clearError: true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .reviewApproval(id, approved, reason: reason);
      if (AppConfig.useLiveApi) {
        return await _confirmRevision(id, approved ? 'Aprobada' : 'Rechazada');
      }
      if (!ref.mounted) return true;
      final approvals = data!.approvals
          .map(
            (item) => item.id == id
                ? item.copyWith(
                    status: approved
                        ? AdminApprovalStatus.approved
                        : AdminApprovalStatus.rejected,
                  )
                : item,
          )
          .toList();
      final pending = approvals
          .where((item) => item.status == AdminApprovalStatus.pending)
          .length;
      state = state.copyWith(
        data: data.copyWith(
          approvals: approvals,
          stats: data.stats.copyWith(pendingApprovals: pending),
        ),
        clearAction: true,
      );
      return true;
    } on AppException catch (error) {
      if (!ref.mounted) return false;
      if (AppConfig.useLiveApi) await load();
      if (!ref.mounted) return false;
      state = state.copyWith(error: error.message, clearAction: true);
      return false;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          error:
              'No se pudo confirmar la revisión. Actualiza antes de repetir.',
          clearAction: true,
        );
      }
      return false;
    }
  }

  Future<bool> finalizeReview(String id, Map<String, dynamic> report) async {
    if (!AppConfig.useLiveApi || state.actionId != null || state.isLoading) {
      return false;
    }
    state = state.copyWith(actionId: id, clearError: true);
    try {
      await (ref.read(adminRepositoryProvider) as ApiAdminRepository)
          .finalizeReview(id, report);
      return await _confirmRevision(id, 'Finalizada');
    } on AppException catch (error) {
      if (ref.mounted) {
        await load();
        if (ref.mounted) {
          state = state.copyWith(error: error.message, clearAction: true);
        }
      }
      return false;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          error: 'No se pudo confirmar el informe. Consulta antes de repetir.',
          clearAction: true,
        );
      }
      return false;
    }
  }

  Future<bool> _confirmRevision(String id, String expected) async {
    final detail = await (ref.read(
      adminRepositoryProvider,
    ) as ApiAdminRepository).fetchRevision(id);
    await load();
    if (!ref.mounted) return false;
    final confirmed =
        detail['estado_solicitud_revision'] == expected && state.error == null;
    if (!confirmed) {
      state = state.copyWith(
        error: 'El cambio pudo guardarse; comprueba el detalle antes de repetirlo.',
      );
    }
    return confirmed;
  }
}

final adminControllerProvider = NotifierProvider<AdminController, AdminState>(
  AdminController.new,
);
