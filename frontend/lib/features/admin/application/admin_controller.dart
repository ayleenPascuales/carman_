import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/admin_models.dart';
import '../../../providers.dart';

class AdminState {
  const AdminState({
    this.data,
    this.isLoading = true,
    this.error,
    this.actionId,
  });

  final AdminDashboardData? data;
  final bool isLoading;
  final String? error;
  final String? actionId;

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
  }) {
    return AdminState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      actionId: clearAction ? null : (actionId ?? this.actionId),
    );
  }
}

class AdminController extends Notifier<AdminState> {
  @override
  AdminState build() {
    Future.microtask(load);
    return const AdminState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ref.read(adminRepositoryProvider).fetchDashboard();
      if (!ref.mounted) return;
      state = AdminState(data: data, isLoading: false);
    } on AppException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'No pudimos cargar la administración.',
      );
    }
  }

  Future<bool> updateUserStatus(String id, AdminUserStatus status) async {
    final data = state.data;
    if (data == null) return false;
    state = state.copyWith(actionId: id, clearError: true);
    try {
      await ref.read(adminRepositoryProvider).updateUserStatus(id, status);
      if (!ref.mounted) return true;
      final users = data.users
          .map((user) => user.id == id ? user.copyWith(status: status) : user)
          .toList();
      state = state.copyWith(
        data: data.copyWith(users: users),
        clearAction: true,
      );
      return true;
    } on AppException catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(error: error.message, clearAction: true);
      return false;
    }
  }

  Future<bool> reviewApproval(String id, bool approved) async {
    final data = state.data;
    if (data == null) return false;
    state = state.copyWith(actionId: id, clearError: true);
    try {
      await ref.read(adminRepositoryProvider).reviewApproval(id, approved);
      if (!ref.mounted) return true;
      final approvals = data.approvals
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
      state = state.copyWith(error: error.message, clearAction: true);
      return false;
    }
  }
}

final adminControllerProvider = NotifierProvider<AdminController, AdminState>(
  AdminController.new,
);
