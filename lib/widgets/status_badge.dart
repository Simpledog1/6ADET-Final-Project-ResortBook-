import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Visual style for a reservation status.
class StatusStyle {
  final Color color; // Solid pill background / tint text colour
  final Color tint; // Light pill background
  final Color dot; // Calendar indicator dot

  const StatusStyle(this.color, this.tint, this.dot);

  static StatusStyle of(String status) {
    final s = status.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    switch (s) {
      case 'checkedin':
        return const StatusStyle(
          AppColors.checkedIn,
          AppColors.checkedInTint,
          AppColors.checkedIn,
        );
      case 'completed':
      case 'checkedout':
        return const StatusStyle(
          AppColors.completed,
          AppColors.completedTint,
          AppColors.completed,
        );
      case 'cancelled':
      case 'canceled':
        return const StatusStyle(
          AppColors.cancelled,
          AppColors.cancelledTint,
          AppColors.cancelledDot,
        );
      case 'reserved':
      default:
        return const StatusStyle(
          AppColors.reserved,
          AppColors.primaryTint,
          AppColors.reserved,
        );
    }
  }
}

/// Rounded status pill ("Reserved", "Checked In", ...).
class StatusBadge extends StatelessWidget {
  final String status;

  /// When true, uses a light background with coloured text
  /// (calendar list style). Otherwise solid colour with white text.
  final bool tinted;
  final double fontSize;
  final double horizontalPadding;

  const StatusBadge({
    super.key,
    required this.status,
    this.tinted = false,
    this.fontSize = 12,
    this.horizontalPadding = 10,
  });

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    final label = status.isEmpty ? 'Reserved' : status;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
      decoration: BoxDecoration(
        color: tinted ? style.tint : style.color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppText.fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 0.2,
          color: tinted ? style.color : Colors.white,
        ),
      ),
    );
  }
}
