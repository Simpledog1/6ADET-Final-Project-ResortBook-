import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// "Active" / "Inactive" pill used in the Manage Resort screens.
class ActiveBadge extends StatelessWidget {
  final bool isActive;

  const ActiveBadge({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.checkedIn : AppColors.completed;
    final background = isActive
        ? AppColors.checkedInTint
        : AppColors.completedTint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontFamily: AppText.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
