import 'package:flutter/material.dart';
import '../screens/add_reservation_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/manage/manage_resort_screen.dart';
import '../screens/manage/rates_screen.dart';
import '../screens/manage/stay_types_screen.dart';
import '../screens/manage/unit_types_screen.dart';
import '../screens/manage/units_screen.dart';
import '../screens/reservation_list_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';
import 'responsive.dart';

/// Root of the app.
///
/// * Phone / tablet (< 1024px): the existing mobile flow, starting at the
///   Dashboard (other screens open with back arrows).
/// * Desktop (≥ 1024px): Figma desktop layout — navy top bar, white sidebar
///   (MAIN MENU + RESORT SETUP) and a content area. Screens opened from a
///   page stay inside the content area, so the sidebar is always visible.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ShellSection _section = ShellSection.dashboard;

  /// Increases on every sidebar click so the content area starts fresh at
  /// the chosen section (even when the same item is clicked again).
  int _navigationCount = 0;

  void _select(ShellSection section) {
    setState(() {
      _section = section;
      _navigationCount++;
    });
  }

  Widget _pageFor(ShellSection section) {
    switch (section) {
      case ShellSection.dashboard:
        return const DashboardScreen();
      case ShellSection.reservations:
        return const ReservationListScreen();
      case ShellSection.calendar:
        return const CalendarScreen();
      case ShellSection.addReservation:
        return const AddReservationScreen();
      case ShellSection.manageResort:
        return const ManageResortScreen();
      case ShellSection.unitTypes:
        return const UnitTypesScreen();
      case ShellSection.units:
        return const UnitsScreen();
      case ShellSection.stayTypes:
        return const StayTypesScreen();
      case ShellSection.rates:
        return const RatesScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Breakpoints.isDesktop(context)) {
      // Mobile / tablet keep the existing navigation (Dashboard hub).
      return const DashboardScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TopBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(selected: _section, onSelect: _select),
                Expanded(
                  child: DesktopShellScope(
                    onNavigate: _select,
                    // Every desktop page uses DesktopPage, which limits its
                    // own content width (1440px) and draws the page header.
                    //
                    // A nested navigator can't share the app's
                    // HeroController, so it gets its own (empty) scope.
                    child: HeroControllerScope.none(
                      child: Navigator(
                        key: ValueKey('shell-$_navigationCount'),
                        onGenerateRoute: (settings) => MaterialPageRoute(
                          settings: settings,
                          builder: (_) => _pageFor(_section),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Navy desktop top bar with the ResortBook logo.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.maybeOf(context);
    return Container(
      height: 64,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 32,
            height: 32,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 8),
          Text('ResortBook', style: AppText.brand.copyWith(fontSize: 22)),
          const Spacer(),
          if (auth != null) ...[
            Text(
              auth.userEmail ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: auth.signOut,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

/// White desktop sidebar: MAIN MENU + RESORT SETUP.
class _Sidebar extends StatelessWidget {
  final ShellSection selected;
  final ValueChanged<ShellSection> onSelect;

  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget item(
      ShellSection section,
      IconData icon,
      String label, {
      bool indent = false,
    }) {
      return _SidebarItem(
        icon: icon,
        label: label,
        indent: indent,
        selected: selected == section,
        onTap: () => onSelect(section),
      );
    }

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const _SidebarLabel('Main menu'),
          item(ShellSection.dashboard, Icons.home_outlined, 'Dashboard'),
          item(
            ShellSection.reservations,
            Icons.assignment_outlined,
            'Reservations',
          ),
          item(
            ShellSection.calendar,
            Icons.calendar_month_outlined,
            'Calendar',
          ),
          item(ShellSection.addReservation, Icons.add, 'Add Reservation'),
          const SizedBox(height: 20),
          const _SidebarLabel('Resort setup'),
          item(ShellSection.manageResort, Icons.tune, 'Manage Resort'),
          item(
            ShellSection.unitTypes,
            Icons.category_outlined,
            'Unit Types',
            indent: true,
          ),
          item(
            ShellSection.units,
            Icons.meeting_room_outlined,
            'Units',
            indent: true,
          ),
          item(
            ShellSection.stayTypes,
            Icons.schedule,
            'Stay Types',
            indent: true,
          ),
          item(
            ShellSection.rates,
            Icons.payments_outlined,
            'Rates',
            indent: true,
          ),
        ],
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  final String text;

  const _SidebarLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Text(text.toUpperCase(), style: AppText.formSection),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool indent;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    final color = selected ? Colors.white : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: indent ? 40 : 44,
            padding: EdgeInsets.only(left: indent ? 36 : 12, right: 12),
            child: Row(
              children: [
                Icon(icon, size: indent ? 16 : 18, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                      fontSize: indent ? 13 : 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
