import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Shared look of the Login and Create Account pages: navy background, the
/// ResortBook logo and a centred white card (max 420 wide, so it works on
/// phone and desktop alike).
class AuthLayout extends StatelessWidget {
  final Widget child;

  const AuthLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 40,
                        height: 40,
                        filterQuality: FilterQuality.medium,
                      ),
                      const SizedBox(width: 8),
                      const Text('ResortBook', style: AppText.brand),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tinted message box used on the auth pages (error = red, success = green).
class AuthMessage extends StatelessWidget {
  final String text;
  final bool isError;

  const AuthMessage({super.key, required this.text, this.isError = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: isError ? AppColors.cancelledTint : AppColors.checkedInTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? AppColors.cancelled : AppColors.checkedIn,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Spinner shown inside the primary button while a request runs.
class AuthButtonSpinner extends StatelessWidget {
  const AuthButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
    );
  }
}
