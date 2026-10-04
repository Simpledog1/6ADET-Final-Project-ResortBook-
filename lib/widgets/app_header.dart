import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Navy header from the Figma wireframe.
///
/// * [AppHeader.home] — centred logo + "ResortBook" (Dashboard).
/// * [AppHeader] — back arrow + screen title (all other screens).
///
/// The navy colour extends behind the system status bar, like the design.
///
/// Used on phones and tablets; desktop pages use `DesktopPage` instead.
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
}
