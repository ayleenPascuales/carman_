import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    super.key,
    required this.password,
    this.showChecks = true,
    this.compact = false,
  });

  final String password;
  final bool showChecks;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final assessment = assessPassword(password);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Seguridad de la clave',
              style: AppTheme.bodySm.copyWith(fontSize: 10.5),
            ),
            const Spacer(),
            Icon(
              assessment.score >= 3
                  ? Icons.verified_user_rounded
                  : Icons.shield_outlined,
              size: 13,
              color: assessment.color,
            ),
            const SizedBox(width: 4),
            Text(
              assessment.label,
              style: AppTheme.labelSm.copyWith(
                color: assessment.color,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(4, (index) {
            final active = index < assessment.score;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                decoration: BoxDecoration(
                  color: active
                      ? assessment.color
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
        ),
        if (showChecks) ...[
          const SizedBox(height: 9),
          for (final check in assessment.checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    check.passed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 13,
                    color: check.passed ? assessment.color : AppColors.border,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    check.label,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: compact ? 10 : 11,
                      color: check.passed
                          ? AppColors.secondaryText
                          : AppColors.tertiaryText,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
