import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Color theme of a [StatCard]'s icon.
enum StatTone { primary, success, warning, neutral, danger }

/// Figma summary card: uppercase label + icon tile on top, a large value,
/// and an optional caption underneath. Generic — it knows nothing about
/// reservations.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final StatTone tone;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.tone = StatTone.primary,
    this.onTap,
  });

  static ({Color color, Color tint}) colorsFor(StatTone tone) {
    switch (tone) {
      case StatTone.primary:
        return (color: AppColors.primary, tint: AppColors.primaryTint);
      case StatTone.success:
        return (color: AppColors.checkedIn, tint: AppColors.checkedInTint);
      case StatTone.warning:
        return (color: AppColors.warning, tint: AppColors.warningTint);
      case StatTone.neutral:
        return (color: AppColors.completed, tint: AppColors.completedTint);
      case StatTone.danger:
        return (color: AppColors.cancelled, tint: AppColors.cancelledTint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(tone);
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: AppText.overline.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: colors.color),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: AppText.cardTitle.copyWith(fontSize: 32, height: 1.2),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(caption!, style: AppText.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
