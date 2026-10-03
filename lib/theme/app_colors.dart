import 'package:flutter/material.dart';

/// Colour tokens taken from the ResortBook Figma wireframe.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1E3A8A); // Navy (header, buttons)
  static const Color primaryTint = Color(0xFFEFF6FF); // Light blue tiles
  static const Color primaryTintBorder = Color(0xFFDBEAFE);

  // Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // Text
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFFCBD5E1);

  // Status
  static const Color reserved = primary;
  static const Color checkedIn = Color(0xFF16A34A);
  static const Color checkedInTint = Color(0xFFDCFCE7);
  static const Color completed = Color(0xFF6B7280);
  static const Color completedTint = Color(0xFFF3F4F6);
  static const Color cancelled = Color(0xFFDC2626);
  static const Color cancelledDot = Color(0xFFF87171);
  static const Color cancelledTint = Color(0xFFFEE2E2);

  // Warning / conflict
  static const Color warning = Color(0xFFF97316);
  static const Color warningTint = Color(0xFFFFEDD5);
  static const Color warningBorder = Color(0xFFFDBA74);
  static const Color warningText = Color(0xFF7C2D12);

  // Disabled button
  static const Color disabled = Color(0xFF94A3B8);
}
