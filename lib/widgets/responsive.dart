import 'package:flutter/material.dart';

/// Screen size classes used across ResortBook.
///
/// * phone   — narrower than 600px
/// * tablet  — 600px to 1023px
/// * desktop — 1024px and wider
enum ScreenSize { phone, tablet, desktop }

class Breakpoints {
  Breakpoints._();

  static const double tablet = 600;
  static const double desktop = 1024;

  static ScreenSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktop) return ScreenSize.desktop;
    if (width >= tablet) return ScreenSize.tablet;
    return ScreenSize.phone;
  }

  static bool isPhone(BuildContext context) => of(context) == ScreenSize.phone;

  static bool isDesktop(BuildContext context) =>
      of(context) == ScreenSize.desktop;
}

/// Sections reachable from the desktop sidebar.
enum ShellSection {
  dashboard,
  reservations,
  calendar,
  addReservation,
  manageResort,
  unitTypes,
  units,
  stayTypes,
  rates,
}

/// Marks widgets that are shown inside the desktop app shell (sidebar
/// layout). Pages use it to switch their header to the desktop style and,
/// for breadcrumbs, to jump to another sidebar section.
class DesktopShellScope extends InheritedWidget {
  /// Switches the shell to a sidebar section (resets the content area).
  final ValueChanged<ShellSection>? onNavigate;

  const DesktopShellScope({super.key, this.onNavigate, required super.child});

  static bool isInside(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopShellScope>() != null;

  /// Opens [section] in the desktop shell. Returns false when not inside
  /// the shell (phone / tablet), so callers can fall back to normal
  /// navigation.
  static bool navigate(BuildContext context, ShellSection section) {
    // Called from tap handlers, so look it up without adding a dependency.
    final scope = context.getInheritedWidgetOfExactType<DesktopShellScope>();
    if (scope?.onNavigate == null) return false;
    scope!.onNavigate!(section);
    return true;
  }

  @override
  bool updateShouldNotify(DesktopShellScope oldWidget) =>
      oldWidget.onNavigate != onNavigate;
}

/// Centers [child] and limits its width so content doesn't stretch across
/// wide windows.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
