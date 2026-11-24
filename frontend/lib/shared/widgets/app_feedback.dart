import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

enum SnackKind { success, error, info, warning }

void showCarmanSnack(
  BuildContext context,
  String message, {
  SnackKind kind = SnackKind.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final (icon, color) = switch (kind) {
    SnackKind.success => (Icons.check_circle_rounded, AppColors.success),
    SnackKind.error => (Icons.error_rounded, AppColors.errorStrong),
    SnackKind.warning => (Icons.warning_amber_rounded, AppColors.warning),
    SnackKind.info => (Icons.info_rounded, AppColors.primaryFixedDim),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyMd.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppColors.primaryFixedDim,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: destructive ? AppColors.error : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(title, style: AppTheme.headlineSm)),
        ],
      ),
      content: Text(
        message,
        style: AppTheme.bodyMd.copyWith(
          color: AppColors.secondaryText,
          height: 1.5,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showProcessingDialog(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
