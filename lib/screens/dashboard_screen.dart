import 'package:flutter/material.dart';
import '../logic/config_rules.dart';
import '../logic/reservation_stats.dart';
import '../models/reservation.dart';
import '../models/unit.dart';
import '../services/config_service.dart';
import '../services/pocketbase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/desktop_page.dart';
import '../widgets/guest_avatar.dart';
import '../widgets/panel_card.dart';
import '../widgets/reservation_cards.dart';
import '../widgets/responsive.dart';
import '../widgets/state_cards.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import 'add_reservation_screen.dart';
import 'calendar_screen.dart';
import 'manage/manage_resort_screen.dart';
import 'reservation_details_screen.dart';
import 'reservation_list_screen.dart';

/// Resort configuration used by the desktop dashboard (unit count for
/// "Units occupied now" and the setup checklist).
class _SetupData {
  final List<Unit> units;
  final List<ChecklistIssue> issues;

  const _SetupData({required this.units, required this.issues});

  int get activeUnitCount => units.where((u) => u.isActive).length;
}

/// Home screen / main hub (Figma "Dashboard").
///
/// * Phone / tablet: upcoming reservations and the hub buttons (unchanged).
/// * Desktop (sidebar shell): greeting, four stat cards, the next three
///   reservations, recently added bookings, quick actions and a setup
///   warning when the resort configuration has problems.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Reservation>> _reservationsFuture;

  /// Loaded only for the desktop layout (null until first needed).
  Future<_SetupData>? _setupFuture;

  @override
  void initState() {
    super.initState();
    _reservationsFuture = PocketBaseService.getReservations();
  }

  void _reload() {
    setState(() {
      _reservationsFuture = PocketBaseService.getReservations();
      if (_setupFuture != null) _setupFuture = _loadSetup();
    });
  }

  /// Same configuration reads as the Manage Resort hub.
  Future<_SetupData> _loadSetup() async {
    final unitTypes = await ConfigService.getUnitTypes();
    final units = await ConfigService.getUnits();
    final stayTypes = await ConfigService.getStayTypes();
    final rates = await ConfigService.getRates();
    return _SetupData(
      units: units,
      issues: ConfigRules.setupChecklist(
        unitTypes: unitTypes,
        units: units,
        stayTypes: stayTypes,
        rates: rates,
      ),
    );
  }

  /// Opens a screen and refreshes the dashboard when the user comes back,
  /// so new reservations show up immediately.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (DesktopShellScope.isInside(context)) return _buildDesktop(context);
    return _buildMobile(context);
  }

  // ── Phone / tablet (unchanged layout, centred on tablets) ─────────────

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader.home(),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => _reload(),
        child: ResponsiveContent(
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
                child: Text(
                  'Upcoming Reservations',
                  style: AppText.sectionTitle,
                ),
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
                      message:
                          'Could not load reservations.\nPull down to retry.',
                    );
                  }
                  final upcoming = ReservationStats.upcoming(
                    snapshot.data ?? [],
                    DateTime.now(),
                  );
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
                          onTap: () =>
                              _open(ReservationDetailsScreen(reservation: res)),
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
              const SizedBox(height: 12),
              // Resort configuration (Stage 4). Outlined to keep the three
              // reservation actions visually primary.
              OutlinedButton.icon(
                onPressed: () => _open(const ManageResortScreen()),
                icon: const Icon(Icons.tune, size: 20),
                label: Text(
                  'Manage Resort',
                  style: AppText.button.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Desktop ────────────────────────────────────────────────────────────

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _goTo(ShellSection section) =>
      DesktopShellScope.navigate(context, section);

  Widget _buildDesktop(BuildContext context) {
    _setupFuture ??= _loadSetup();
    final now = DateTime.now();

    return DesktopPage(
      title: _greeting(now),
      subtitle:
          '${DateFormatUtil.fullDate(now)} · '
          "Here's what's happening at your resort.",
      onRefresh: () async => _reload(),
      children: [
        // Setup warning (only when the checklist has problems).
        FutureBuilder<_SetupData>(
          future: _setupFuture,
          builder: (context, snapshot) {
            final issues = snapshot.data?.issues ?? const <ChecklistIssue>[];
            if (issues.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _SetupWarningCard(
                issues: issues,
                onOpen: () => _goTo(ShellSection.manageResort),
              ),
            );
          },
        ),
        FutureBuilder<List<Reservation>>(
          future: _reservationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg * 2),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return LoadErrorCard(
                message: 'Could not load reservations.\n${snapshot.error}',
                onRetry: _reload,
              );
            }
            return _buildDesktopContent(snapshot.data ?? const [], now);
          },
        ),
      ],
    );
  }

  Widget _buildDesktopContent(List<Reservation> all, DateTime now) {
    final upcoming = ReservationStats.upcoming(all, now);
    final recent = ReservationStats.recentlyAdded(all);
    final staying = ReservationStats.stayingNow(all, now);
    final arriving = ReservationStats.arrivingWithin(all, now);
    final occupied = ReservationStats.unitsOccupiedNow(all, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Stats ──
        FutureBuilder<_SetupData>(
          future: _setupFuture,
          builder: (context, snapshot) {
            final activeUnits = snapshot.data?.activeUnitCount;
            return _StatRow(
              cards: [
                StatCard(
                  label: 'Reservations this month',
                  value: '${ReservationStats.reservationsThisMonth(all, now)}',
                  caption: 'Check-ins in ${DateFormatUtil.monthYear(now)}',
                  icon: Icons.event_note,
                ),
                StatCard(
                  label: 'Staying now',
                  value: '${staying.length}',
                  caption: staying.length == 1
                      ? 'Reservation in progress'
                      : 'Reservations in progress',
                  icon: Icons.hotel_outlined,
                  tone: StatTone.success,
                ),
                StatCard(
                  label: 'Arriving in next 7 days',
                  value: '${arriving.length}',
                  caption: arriving.isEmpty
                      ? 'No arrivals this week'
                      : 'Next: ${DateFormatUtil.monthDayTime(arriving.first.startAt)}',
                  icon: Icons.login,
                  tone: StatTone.warning,
                ),
                StatCard(
                  label: 'Units occupied now',
                  value: activeUnits == null || activeUnits == 0
                      ? '$occupied'
                      : '$occupied / $activeUnits',
                  caption: activeUnits == null
                      ? 'Units with a guest right now'
                      : 'Of $activeUnits active unit${activeUnits == 1 ? '' : 's'}',
                  icon: Icons.meeting_room_outlined,
                  tone: StatTone.neutral,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Upcoming reservations ──
        Row(
          children: [
            const Expanded(
              child: Text('Upcoming Reservations', style: AppText.sectionTitle),
            ),
            TextButton(
              onPressed: () => _goTo(ShellSection.reservations),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('View all →'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          const EmptyStateCard(
            icon: Icons.event_busy_outlined,
            message: 'No upcoming reservations.',
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: i < upcoming.length
                        ? _UpcomingCard(
                            reservation: upcoming[i],
                            onView: () => _open(
                              ReservationDetailsScreen(
                                reservation: upcoming[i],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),

        // ── Recently added + quick actions ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: PanelCard(
                title: 'Recently Added',
                subtitle: 'Latest bookings by date created',
                icon: Icons.history,
                child: recent.isEmpty
                    ? Text(
                        'No recently added reservations.',
                        style: AppText.bodySecondary.copyWith(
                          color: AppColors.textMuted,
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < recent.length; i++)
                            _RecentRow(
                              reservation: recent[i],
                              showDivider: i > 0,
                              onTap: () => _open(
                                ReservationDetailsScreen(
                                  reservation: recent[i],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              flex: 2,
              child: PanelCard(
                title: 'Quick Actions',
                icon: Icons.bolt_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QuickAction(
                      icon: Icons.edit_calendar_outlined,
                      label: 'Add Reservation',
                      primary: true,
                      onTap: () => _goTo(ShellSection.addReservation),
                    ),
                    _QuickAction(
                      icon: Icons.format_list_bulleted,
                      label: 'View Reservations',
                      onTap: () => _goTo(ShellSection.reservations),
                    ),
                    _QuickAction(
                      icon: Icons.calendar_today_outlined,
                      label: 'View Calendar',
                      onTap: () => _goTo(ShellSection.calendar),
                    ),
                    _QuickAction(
                      icon: Icons.tune,
                      label: 'Manage Resort',
                      onTap: () => _goTo(ShellSection.manageResort),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
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
      label: Text(label, style: AppText.button.copyWith(fontSize: 14)),
    );
  }
}

/// Four stat cards in one row, two rows of two when space is tight.
class _StatRow extends StatelessWidget {
  final List<Widget> cards;

  const _StatRow({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.md;
        final perRow = constraints.maxWidth >= 860 ? 4 : 2;
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

/// Orange warning listing setup checklist problems.
class _SetupWarningCard extends StatelessWidget {
  final List<ChecklistIssue> issues;
  final VoidCallback onOpen;

  static const int _maxShown = 3;

  const _SetupWarningCard({required this.issues, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final shown = issues.take(_maxShown).toList();
    final more = issues.length - shown.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          color: AppColors.warningTint,
          border: Border(left: BorderSide(color: AppColors.warning, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resort setup needs attention',
                    style: AppText.valueStrong.copyWith(
                      color: AppColors.warningText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final issue in shown)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '• ${issue.message}',
                        style: AppText.body.copyWith(
                          fontSize: 13,
                          color: AppColors.warningText,
                        ),
                      ),
                    ),
                  if (more > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '…and $more more',
                        style: AppText.caption.copyWith(
                          color: AppColors.warningText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warningText,
              ),
              child: const Text('Open Manage Resort'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desktop "Upcoming Reservations" card.
class _UpcomingCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onView;

  const _UpcomingCard({required this.reservation, required this.onView});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final unit = r.unitDisplayName.isEmpty ? '—' : r.unitDisplayName;
    final type = r.unitTypeDisplayName;
    final guests = r.guestCount > 0
        ? '${r.guestCount} guest${r.guestCount == 1 ? '' : 's'}'
        : null;

    return AppCard(
      onTap: onView,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GuestAvatar(name: r.guestName, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.guestName.isEmpty ? '—' : r.guestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.valueStrong.copyWith(fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: r.status, tinted: true, fontSize: 11),
            ],
          ),
          const SizedBox(height: 12),
          _iconLine(
            Icons.meeting_room_outlined,
            type.isEmpty ? unit : '$unit · $type',
          ),
          _iconLine(
            Icons.schedule,
            guests == null
                ? r.stayTypeDisplayName
                : '${r.stayTypeDisplayName} · $guests',
          ),
          _iconLine(
            Icons.event,
            DateFormatUtil.stayRange(r.startAt, r.endAt, datesOnly: r.isLegacy),
          ),
          const SizedBox(height: 12),
          const Spacer(),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  r.totalAmount > 0 ? CurrencyFormat.peso(r.totalAmount) : '—',
                  style: AppText.valueStrong.copyWith(color: AppColors.primary),
                ),
              ),
              TextButton(
                onPressed: onView,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppText.body.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the "Recently Added" panel.
class _RecentRow extends StatelessWidget {
  final Reservation reservation;
  final bool showDivider;
  final VoidCallback onTap;

  const _RecentRow({
    required this.reservation,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final unit = r.unitDisplayName.isEmpty ? '—' : r.unitDisplayName;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(top: BorderSide(color: AppColors.divider))
              : null,
        ),
        child: Row(
          children: [
            GuestAvatar(name: r.guestName, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.guestName.isEmpty ? '—' : r.guestName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.valueStrong,
                  ),
                  Text(
                    '$unit · ${r.stayTypeDisplayName} · '
                    '${DateFormatUtil.monthDay(r.startAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(status: r.status, tinted: true, fontSize: 11),
                const SizedBox(height: 4),
                Text(
                  'Added ${DateFormatUtil.monthDayTime(r.createdAt!)}',
                  style: AppText.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Button row in the "Quick Actions" panel.
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    final fg = primary ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: primary ? AppColors.primary : AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: primary ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: primary ? Colors.white : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.value.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: primary ? Colors.white : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
