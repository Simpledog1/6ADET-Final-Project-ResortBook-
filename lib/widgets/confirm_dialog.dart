import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Compact button styles for dialogs and toolbars. The app theme makes
/// buttons full-width (56px tall) for forms, which doesn't fit in rows.
class CompactButtons {
  CompactButtons._();

  static ButtonStyle filled({Color background = AppColors.primary}) {
    return FilledButton.styleFrom(
      backgroundColor: background,
      minimumSize: const Size(96, 44),
      padding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  static ButtonStyle outlined({Color color = AppColors.primary}) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(96, 44),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      side: BorderSide(color: color, width: 1.5),
    );
  }
}

/// Shows a confirmation dialog and returns true when the user confirms.
///
/// [details] is an optional extra widget shown under the message.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  Widget? details,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
      details: details,
    ),
  );
  return result ?? false;
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final Widget? details;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      title: Text(title, style: AppText.cardTitle.copyWith(fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: AppText.bodySecondary),
            if (details != null) ...[const SizedBox(height: 12), details!],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: CompactButtons.outlined(color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: CompactButtons.filled(
            background: destructive ? AppColors.cancelled : AppColors.primary,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
