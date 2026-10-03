import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// White rounded card with the soft Figma shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;

  static const List<BoxShadow> defaultShadow = [
    BoxShadow(color: Color(0x14000000), offset: Offset(0, 2), blurRadius: 4),
  ];

  static const List<BoxShadow> largeShadow = [
    BoxShadow(color: Color(0x14000000), offset: Offset(0, 4), blurRadius: 20),
  ];

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppSpacing.radiusLg,
    this.onTap,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: borderRadius,
        boxShadow: shadow ?? defaultShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
