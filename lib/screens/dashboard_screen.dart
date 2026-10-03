import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../services/pocketbase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/app_header.dart';
import '../widgets/reservation_cards.dart';
import 'add_reservation_screen.dart';
import 'calendar_screen.dart';
import 'reservation_details_screen.dart';
import 'reservation_list_screen.dart';

/// Home screen / main hub (Figma "Dashboard").
///
/// Shows upcoming reservations and three buttons that open
/// Add Reservation, Reservation List and Calendar.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Reservation>> _reservationsFuture;

  @override
  void initState() {
    super.initState();
    _reservationsFuture = PocketBaseService.getReservations();
  }

  void _reload() {
    setState(() {
      _reservationsFuture = PocketBaseService.getReservations();
    });
  }

  /// Opens a screen and refreshes the dashboard when the user comes back,
  /// so new reservations show up immediately.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) _reload();
  }

  /// Reservations that haven't ended yet, soonest first (max 3).
  List<Reservation> _upcoming(List<Reservation> all) {
    final today = DateFormatUtil.dateOnly(DateTime.now());
    final list = all
        .where((r) => !DateFormatUtil.dateOnly(r.checkOutDate).isBefore(today))
        .toList()
      ..sort((a, b) => a.checkInDate.compareTo(b.checkInDate));
    return list.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader.home(),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Text('Upcoming Reservations', style: AppText.sectionTitle),
            ),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<Reservation>>(
              future: _reservationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const EmptyStateCard(
                    icon: Icons.cloud_off_outlined,
                    message: 'Could not load reservations.\nPull down to retry.',
                  );
                }
                final upcoming = _upcoming(snapshot.data ?? []);
                if (upcoming.isEmpty) {
                  return const EmptyStateCard(
                    icon: Icons.event_busy_outlined,
                    message: 'No upcoming reservations.',
                  );
                }
                return Column(
                  children: [
                    for (final res in upcoming) ...[
                      UpcomingReservationCard(
                        reservation: res,
                        onTap: () => _open(
                          ReservationDetailsScreen(reservation: res),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _HubButton(
              icon: Icons.edit_calendar_outlined,
              label: 'Add Reservation',
              onPressed: () => _open(const AddReservationScreen()),
            ),
            const SizedBox(height: 12),
            _HubButton(
              icon: Icons.format_list_bulleted,
              label: 'View Reservations',
              onPressed: () => _open(const ReservationListScreen()),
            ),
            const SizedBox(height: 12),
            _HubButton(
              icon: Icons.calendar_today_outlined,
              label: 'View Calendar',
              onPressed: () => _open(const CalendarScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width navy action button used on the dashboard.
class _HubButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _HubButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: AppText.button.copyWith(fontSize: 14),
      ),
    );
  }
}
