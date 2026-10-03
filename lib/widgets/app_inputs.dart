import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Shared input styling from the Figma form (white box, 1px slate border,
/// 12px radius, 56px tall, leading grey icon).
class AppInputs {
  AppInputs._();

  static OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static InputDecoration decoration({
    String? hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.body.copyWith(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 17.5,
      ),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: AppColors.textMuted),
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 20),
      suffixIcon: suffix,
      border: _border(AppColors.border),
      enabledBorder: _border(AppColors.border),
      focusedBorder: _border(AppColors.primary, 1.5),
      errorBorder: _border(AppColors.cancelled),
      focusedErrorBorder: _border(AppColors.cancelled, 1.5),
      errorStyle: AppText.caption.copyWith(color: AppColors.cancelled),
    );
  }
}

/// Small label shown above a form field ("Guest Name").
class FieldLabel extends StatelessWidget {
  final String text;
  final Widget child;

  const FieldLabel({super.key, required this.text, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: AppText.fieldLabel),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Uppercase form section header ("GUEST INFORMATION").
class FormSectionHeader extends StatelessWidget {
  final String text;
  final double topPadding;

  const FormSectionHeader(this.text, {super.key, this.topPadding = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Text(text.toUpperCase(), style: AppText.formSection),
    );
  }
}

/// Tappable box that looks like an input, used for date pickers.
class PickerField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final IconData trailingIcon;
  final VoidCallback onTap;
  final bool highlightError;

  const PickerField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.trailingIcon = Icons.calendar_today_outlined,
    this.highlightError = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: AppSpacing.buttonHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: highlightError ? AppColors.warning : AppColors.border,
              width: highlightError ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? placeholder,
                  style: value == null
                      ? AppText.body.copyWith(color: AppColors.textMuted)
                      : AppText.body,
                ),
              ),
              Icon(trailingIcon, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
