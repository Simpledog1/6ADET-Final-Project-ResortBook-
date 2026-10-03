import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// One step of a breadcrumb trail. Items with [onTap] are clickable;
/// the last item is the current page.
class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  const BreadcrumbItem(this.label, {this.onTap});
}

/// Figma breadcrumb: "Reservations › Reservation Details".
class Breadcrumbs extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const Breadcrumbs({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;
      final style = AppText.caption.copyWith(
        color: isLast ? AppColors.textPrimary : AppColors.textMuted,
        fontWeight: isLast ? FontWeight.w500 : FontWeight.w400,
      );

      if (item.onTap != null && !isLast) {
        children.add(
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: item.onTap,
              child: Text(item.label, style: style),
            ),
          ),
        );
      } else {
        children.add(Text(item.label, style: style));
      }

      if (!isLast) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.chevron_right,
              size: 14,
              color: AppColors.textMuted,
            ),
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// Desktop page frame used inside the sidebar shell (Figma desktop):
///
/// ```
/// Breadcrumb › Trail
/// Page Title                                   [actions]
/// Subtitle
/// ─ content ─
/// ```
///
/// Content is centered and limited to [maxWidth] (default 1440px) with the
/// standard desktop padding. Use it only for desktop layouts — phone and
/// tablet keep their existing screens.
class DesktopPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<BreadcrumbItem> breadcrumbs;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double maxWidth;

  /// Shows a back arrow before the title when the page can be popped.
  /// Breadcrumbs are the main way back; the arrow covers pages that were
  /// opened from another page (e.g. Dashboard → Manage Resort).
  final bool showBackButton;

  static const double defaultMaxWidth = 1440;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(32, 24, 32, 48);

  const DesktopPage({
    super.key,
    required this.title,
    this.subtitle,
    this.breadcrumbs = const [],
    this.actions = const [],
    required this.children,
    this.onRefresh,
    this.maxWidth = defaultMaxWidth,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final canGoBack = showBackButton && Navigator.of(context).canPop();

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (breadcrumbs.isNotEmpty) ...[
          Breadcrumbs(items: breadcrumbs),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canGoBack) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Back',
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.cardTitle.copyWith(
                      fontSize: 28,
                      height: 1.3,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: AppText.bodySecondary),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.md),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );

    Widget body = ListView(
      padding: padding,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, ...children],
            ),
          ),
        ),
      ],
    );

    if (onRefresh != null) {
      body = RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh!,
        child: body,
      );
    }

    return Scaffold(backgroundColor: AppColors.background, body: body);
  }
}
