import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'responsive.dart';

/// Navy header from the Figma wireframe.
///
/// * [AppHeader.home] — centred logo + "ResortBook" (Dashboard).
/// * [AppHeader] — back arrow + screen title (all other screens).
///
/// The navy colour extends behind the system status bar, like the design.
///
/// Inside the desktop app shell (sidebar layout) the shell already shows the
/// navy top bar, so the header becomes a Figma-style page title row instead,
/// with a back arrow only when there is a page to go back to.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isHome;
  final VoidCallback? onBack;

  const AppHeader({super.key, required this.title, this.onBack})
    : isHome = false;

  const AppHeader.home({super.key})
    : title = 'ResortBook',
      isHome = true,
      onBack = null;

  @override
  Size get preferredSize => const Size.fromHeight(AppSpacing.headerHeight);

  @override
  Widget build(BuildContext context) {
    if (DesktopShellScope.isInside(context)) {
      return _buildDesktopTitle(context);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: AppColors.primary,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppSpacing.headerHeight,
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.sm,
              ),
              child: isHome ? _buildHome() : _buildWithBack(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHome() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 34,
          height: 34,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 6),
        Text(title, style: AppText.brand),
      ],
    );
  }

  Widget _buildWithBack(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: AppText.headerTitle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Desktop page title row (used inside the sidebar shell).
  Widget _buildDesktopTitle(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();
    return Container(
      height: AppSpacing.headerHeight,
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 0),
      child: Row(
        children: [
          if (canGoBack) ...[
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              isHome ? 'Dashboard' : title,
              style: AppText.cardTitle.copyWith(fontSize: 24, height: 1.3),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
