import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Circle with a guest's initials ("Maria Santos" → "MS").
class GuestAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;

  const GuestAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = Colors.white,
  });

  /// First letter of the first and last words; "?" for an empty name.
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontFamily: AppText.fontFamily,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: foregroundColor,
        ),
      ),
    );
  }
}
