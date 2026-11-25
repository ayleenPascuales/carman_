import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../notifications/application/notifications_controller.dart';

class LicenseState {
  const LicenseState({
    this.status = LicenseStatus.notSubmitted,
    this.frontBytes,
    this.backBytes,
    this.frontAsset,
    this.backAsset,
    this.isSubmitting = false,
    this.error,
    this.rejectionReason,
    this.submittedAt,
    this.estimatedCompletion,
    this.approvedAt,
  });

  final LicenseStatus status;
  final Uint8List? frontBytes;
  final Uint8List? backBytes;
  final String? frontAsset;
  final String? backAsset;
  final bool isSubmitting;
  final String? error;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? estimatedCompletion;
  final DateTime? approvedAt;

  bool get hasFront => frontBytes != null || frontAsset != null;

  bool get hasBack => backBytes != null || backAsset != null;

  bool get isApproved => status == LicenseStatus.approved;

  bool get needsAction =>
      status == LicenseStatus.notSubmitted || status == LicenseStatus.rejected;

  LicenseState copyWith({
    LicenseStatus? status,
    Uint8List? frontBytes,
    Uint8List? backBytes,
    String? frontAsset,
    String? backAsset,
    bool? isSubmitting,
    String? error,
    String? rejectionReason,
    DateTime? submittedAt,
    DateTime? estimatedCompletion,
    DateTime? approvedAt,
    bool clearError = false,
  }) {
    return LicenseState(
      status: status ?? this.status,
      frontBytes: frontBytes ?? this.frontBytes,
      backBytes: backBytes ?? this.backBytes,
      frontAsset: frontAsset ?? this.frontAsset,
      backAsset: backAsset ?? this.backAsset,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
      estimatedCompletion: estimatedCompletion ?? this.estimatedCompletion,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}

class LicenseController extends Notifier<LicenseState> {
  Timer? _demoReviewTimer;

  @override
  LicenseState build() {
    // Reset when a different account signs in, but not on ordinary profile
    // updates (the select only emits when the id changes).
    ref.watch(authControllerProvider.select((state) => state.user?.id));
    ref.onDispose(() => _demoReviewTimer?.cancel());
    final user = ref.read(authControllerProvider).user;
    final status = user?.licenseStatus ?? LicenseStatus.notSubmitted;
    return LicenseState(
      status: status,
      frontAsset:
          status == LicenseStatus.rejected || status == LicenseStatus.approved
          ? AppAssets.licenseSample
          : null,
      rejectionReason: status == LicenseStatus.rejected
          ? 'El documento presentado estaba borroso o caducado. Sube una foto nítida de tu permiso vigente.'
          : null,
      approvedAt: status == LicenseStatus.approved ? DateTime.now() : null,
    );
  }

  void setFrontImage(Uint8List bytes) {
    state = state.copyWith(frontBytes: bytes, clearError: true);
  }

  void setBackImage(Uint8List bytes) {
    state = state.copyWith(backBytes: bytes, clearError: true);
  }

  void useDemoFront() {
    state = state.copyWith(
      frontAsset: AppAssets.licenseSample,
      status: state.status == LicenseStatus.rejected
          ? LicenseStatus.rejected
          : state.status,
      clearError: true,
    );
  }

  Future<bool> submit({
    required String number,
    required DateTime expiry,
    String type = 'B',
  }) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return false;
    if (!state.hasFront) {
      state = state.copyWith(
        error: 'Carga la foto frontal de tu licencia para continuar.',
      );
      return false;
    }
    if (expiry.isBefore(DateTime.now())) {
      state = state.copyWith(error: 'La licencia no puede estar vencida.');
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .submitLicense(
            user,
            LicenseSubmission(
              number: number,
              expiry: expiry,
              type: type,
              frontImageReference: state.frontBytes != null
                  ? 'local://licencia/frontal'
                  : state.frontAsset!,
              backImageReference: state.backBytes != null
                  ? 'local://licencia/reverso'
                  : state.backAsset,
            ),
          );
      await ref.read(authControllerProvider.notifier).updateUser(updated);
      final now = DateTime.now();
      state = state.copyWith(
        status: LicenseStatus.pendingReview,
        isSubmitting: false,
        submittedAt: now,
        estimatedCompletion: now.add(const Duration(minutes: 15)),
        clearError: true,
      );
      ref
          .read(notificationsControllerProvider.notifier)
          .addLicenseUpdate(approved: false);
      // Demo automation: the API would push a verification result. We emulate
      // a fast reviewer so the full approved state can be experienced.
      _demoReviewTimer?.cancel();
      _demoReviewTimer = Timer(const Duration(seconds: 15), _approveInDemo);
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSubmitting: false, error: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'No pudimos enviar tu licencia. Inténtalo de nuevo.',
      );
      return false;
    }
  }

  Future<void> _approveInDemo() async {
    if (!ref.mounted) return;
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final approved = user.copyWith(licenseStatus: LicenseStatus.approved);
    await ref.read(authControllerProvider.notifier).updateUser(approved);
    if (!ref.mounted) return;
    state = state.copyWith(
      status: LicenseStatus.approved,
      approvedAt: DateTime.now(),
      frontAsset: state.frontAsset ?? AppAssets.licenseSample,
      clearError: true,
    );
    ref
        .read(notificationsControllerProvider.notifier)
        .addLicenseUpdate(approved: true);
  }

  /// Used by the in-app demo toolbox to showcase the rejected upload state.
  Future<void> simulateRejection() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final rejected = user.copyWith(licenseStatus: LicenseStatus.rejected);
    await ref.read(authControllerProvider.notifier).updateUser(rejected);
    state = LicenseState(
      status: LicenseStatus.rejected,
      frontAsset: AppAssets.licenseSample,
      rejectionReason: 'El documento presentado estaba borroso o caducado. Sube una foto nítida de tu permiso vigente.',
    );
  }

  /// Allows an already verified user to upload a renewed licence.
  Future<void> startRenewal() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    _demoReviewTimer?.cancel();
    final reset = user.copyWith(licenseStatus: LicenseStatus.notSubmitted);
    await ref.read(authControllerProvider.notifier).updateUser(reset);
    state = LicenseState(
      status: LicenseStatus.notSubmitted,
      frontAsset: state.frontAsset,
      backAsset: state.backAsset,
    );
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

final licenseControllerProvider =
    NotifierProvider<LicenseController, LicenseState>(LicenseController.new);
