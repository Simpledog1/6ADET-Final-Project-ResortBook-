import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'app_header.dart';
import 'responsive.dart';

/// Opens a form the right way for the screen size:
/// * phone — full-screen page with the navy header and a back arrow
/// * tablet / desktop — centered dialog (max 560px wide)
///
/// The form itself calls `Navigator.of(context).pop(result)` when done.
Future<T?> showAdaptiveForm<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  if (Breakpoints.isPhone(context)) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        fullscreenDialog: true,
        builder: (pageContext) => Scaffold(
          appBar: AppHeader(title: title),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              20,
              AppSpacing.md,
              AppSpacing.lg * 2,
            ),
            child: builder(pageContext),
          ),
        ),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppText.cardTitle.copyWith(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: builder(dialogContext),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
