// Shared search box and filter chips (Manage Resort, and later the
// Reservation List and Calendar).
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Rounded search box (same look as the Reservation List search).
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color),
    );

    return SizedBox(
      height: AppSpacing.searchHeight,
      child: TextField(
        controller: controller,
        style: AppText.body,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.body.copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13.5),
          border: border(AppColors.border),
          enabledBorder: border(AppColors.border),
          focusedBorder: border(AppColors.primary),
        ),
      ),
    );
  }
}

/// Pill-shaped filter options (Figma "All / Reserved / …" chips).
///
/// [counts] is optional; when given (same length as [values]) each chip
/// shows its count, e.g. "Reserved 4".
class FilterChipBar<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onSelected;
  final List<int>? counts;

  const FilterChipBar({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final showCounts = counts != null && counts!.length == values.length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < values.length; i++)
          _chip(
            labels[i],
            showCounts ? counts![i] : null,
            values[i] == selected,
            () => onSelected(values[i]),
          ),
      ],
    );
  }

  Widget _chip(String label, int? count, bool isSelected, VoidCallback onTap) {
    final radius = BorderRadius.circular(999);
    final textColor = isSelected ? Colors.white : AppColors.textPrimary;
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppText.value.copyWith(fontSize: 13, color: textColor),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.divider,
                    borderRadius: radius,
                  ),
                  child: Text(
                    '$count',
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
