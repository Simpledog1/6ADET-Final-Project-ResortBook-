import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Figma desktop details item:
///
/// ```
/// CONTACT NUMBER
/// [icon]  +63 917 123 4567
/// ```
///
/// Empty values show [emptyText] ("—") so missing data is obvious.
/// Pass [valueWidget] instead of [value] for rich content (e.g. a badge).
class InfoTile extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final IconData? icon;
  final String? supportingText;
  final String emptyText;

  const InfoTile({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.icon,
    this.supportingText,
    this.emptyText = '—',
  });

  @override
  Widget build(BuildContext context) {
    final text = (value == null || value!.trim().isEmpty) ? emptyText : value!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.overline),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  valueWidget ??
                      Text(
                        text,
                        style: AppText.valueStrong.copyWith(
                          color: text == emptyText
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                  if (supportingText != null && supportingText!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs / 2),
                      child: Text(supportingText!, style: AppText.caption),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
