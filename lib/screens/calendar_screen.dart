import 'package:flutter/material.dart';
import '../logic/calendar_logic.dart';
import '../logic/reservation_workflow.dart';
import '../models/reservation.dart';
import '../services/config_service.dart';
import '../services/reservation_gateway.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/desktop_page.dart';
import '../widgets/panel_card.dart';
import '../widgets/reservation_cards.dart';
import '../widgets/responsive.dart';
import '../widgets/state_cards.dart';
import '../widgets/status_badge.dart';
import 'add_reservation_screen.dart';
import 'reservation_details_screen.dart';

/// Reservation Calendar (Figma "Calendar View").
///
/// * Phone / tablet: month grid with a coloured dot on every day that has
///   a booking and the selected day's reservations underneath (unchanged).
/// * Desktop (sidebar shell): large month grid with booking bars, and a
///   320px panel with the selected day, other reservations this month and
///   "Add New Reservation".
///
/// Which bookings belong on which day comes from [CalendarLogic] (a booking
/// shows on every day its actual time window touches).
class CalendarScreen extends StatefulWidget {
  /// PocketBase access; tests pass a fake.
  final ReservationGateway gateway;

  /// Current time (which month and day open first); tests pass a fixed
  /// clock. Defaults to [DateTime.now].
  final DateTime Function()? clock;

  const CalendarScreen({
    super.key,
    this.gateway = const ReservationGateway(),
    this.clock,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<List<Reservation>> _reservationsFuture;
  late DateTime _focusedMonth; // First day of the visible month
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = DateFormatUtil.dateOnly(_now());
    _selectedDay = today;
    _focusedMonth = DateTime(today.year, today.month);
    _reservationsFuture = widget.gateway.getReservations();
  }

  void _reload() {
    setState(() {
      _reservationsFuture = widget.gateway.getReservations();
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  void _goToToday() {
    final today = DateFormatUtil.dateOnly(_now());
    setState(() {
      _selectedDay = today;
      _focusedMonth = DateTime(today.year, today.month);
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      if (day.month != _focusedMonth.month || day.year != _focusedMonth.year) {
        _focusedMonth = DateTime(day.year, day.month);
      }
    });
  }

  /// Reservations whose actual time window touches [day], active first.
  List<Reservation> _reservationsOn(List<Reservation> all, DateTime day) =>
      CalendarLogic.reservationsOn(all, day);

  /// Opens Details; reloads when it reports a change (edit, cancel,
  /// check-in, complete or restore).
  Future<void> _openDetails(Reservation res) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ReservationDetailsScreen(reservation: res, gateway: widget.gateway),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddReservationScreen(gateway: widget.gateway),
      ),
    );
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
      appBar: const AppHeader(title: 'Reservation Calendar'),
      body: FutureBuilder<List<Reservation>>(
        future: _reservationsFuture,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final all = snapshot.data ?? const <Reservation>[];
          final dayReservations = _reservationsOn(all, _selectedDay);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => _reload(),
            child: ResponsiveContent(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  12,
                  AppSpacing.md,
                  AppSpacing.lg * 1.5,
                ),
                children: [
                  _MonthCalendar(
                    focusedMonth: _focusedMonth,
                    selectedDay: _selectedDay,
                    reservations: all,
                    reservationsOn: _reservationsOn,
                    onPrev: () => _changeMonth(-1),
                    onNext: () => _changeMonth(1),
                    onSelect: _selectDay,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Reservations on ${DateFormatUtil.monthDay(_selectedDay)}',
                    style: AppText.sectionTitle,
                  ),
                  const SizedBox(height: 12),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    const EmptyStateCard(
                      icon: Icons.cloud_off_outlined,
                      message:
                          'Could not load reservations.\nPull down to retry.',
                    )
                  else if (dayReservations.isEmpty)
                    const EmptyStateCard(
                      icon: Icons.event_available_outlined,
                      message: 'No reservations on this day.',
                    )
                  else
                    for (final res in dayReservations) ...[
                      CalendarReservationCard(
                        reservation: res,
                        onTap: () => _openDetails(res),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Desktop ────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return DesktopPage(
      title: 'Calendar',
      subtitle: 'Every reservation by day. Click a day to see its bookings.',
      onRefresh: () async => _reload(),
      actions: [
        OutlinedButton(
          style: CompactButtons.outlined(),
          onPressed: _goToToday,
          child: const Text('Today'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Previous month',
              onTap: () => _changeMonth(-1),
            ),
            SizedBox(
              width: 150,
              child: Text(
                DateFormatUtil.monthYear(_focusedMonth),
                textAlign: TextAlign.center,
                style: AppText.cardTitle.copyWith(fontSize: 18, height: 1.5),
              ),
            ),
            _RoundIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Next month',
              onTap: () => _changeMonth(1),
            ),
          ],
        ),
      ],
      children: [
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
                message:
                    'Could not load reservations.\n'
                    '${ConfigService.friendlyError(snapshot.error!)}',
                onRetry: _reload,
              );
            }
            final all = snapshot.data ?? const <Reservation>[];

            final grid = _DesktopMonthGrid(
              focusedMonth: _focusedMonth,
              selectedDay: _selectedDay,
              reservations: all,
              onSelect: _selectDay,
              onOpen: _openDetails,
            );
            final panel = _DesktopDayPanel(
              selectedDay: _selectedDay,
              focusedMonth: _focusedMonth,
              reservations: all,
              onOpen: _openDetails,
              onAdd: _openAdd,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                // Side panel next to the grid when there is room for both,
                // otherwise underneath (narrow desktop windows).
                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: grid),
                      const SizedBox(width: AppSpacing.lg),
                      SizedBox(width: 320, child: panel),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    grid,
                    const SizedBox(height: AppSpacing.lg),
                    panel,
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Desktop month grid: tall day cells with up to three booking bars.
class _DesktopMonthGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<Reservation> reservations;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<Reservation> onOpen;

  const _DesktopMonthGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.reservations,
    required this.onSelect,
    required this.onOpen,
  });

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final days = CalendarLogic.monthGridDays(focusedMonth);
    final today = DateFormatUtil.dateOnly(DateTime.now());
    final weeks = <List<DateTime>>[
      for (var i = 0; i < days.length; i += 7) days.sublist(i, i + 7),
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weekday labels
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                for (final w in _weekdays)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        w.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppText.overline.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Weeks
          for (var w = 0; w < weeks.length; w++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _DesktopDayCell(
                      day: weeks[w][d],
                      inMonth: weeks[w][d].month == focusedMonth.month,
                      isToday: DateFormatUtil.isSameDay(weeks[w][d], today),
                      isSelected: DateFormatUtil.isSameDay(
                        weeks[w][d],
                        selectedDay,
                      ),
                      bookings: CalendarLogic.reservationsOn(
                        reservations,
                        weeks[w][d],
                      ),
                      showRightBorder: d < 6,
                      showBottomBorder: w < weeks.length - 1,
                      onTap: () => onSelect(weeks[w][d]),
                      onOpen: onOpen,
                    ),
                  ),
              ],
            ),

          // Legend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: const Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _LegendItem(status: ReservationStatus.reserved),
                _LegendItem(status: ReservationStatus.checkedIn),
                _LegendItem(status: ReservationStatus.completed),
                _LegendItem(status: ReservationStatus.cancelled),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopDayCell extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<Reservation> bookings;
  final bool showRightBorder;
  final bool showBottomBorder;
  final VoidCallback onTap;
  final ValueChanged<Reservation> onOpen;

  const _DesktopDayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.bookings,
    required this.showRightBorder,
    required this.showBottomBorder,
    required this.onTap,
    required this.onOpen,
  });

  static const int _maxBars = 3;
  static const double height = 132;

  @override
  Widget build(BuildContext context) {
    final shown = bookings.take(_maxBars).toList();
    final more = bookings.length - shown.length;

    Color numberColor = inMonth
        ? AppColors.textPrimary
        : AppColors.textDisabled;
    BoxDecoration? numberDecoration;
    if (isToday) {
      numberColor = Colors.white;
      numberDecoration = const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      );
    }

    return Material(
      color: isSelected
          ? AppColors.primaryTint
          : (inMonth ? AppColors.surface : AppColors.background),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          decoration: BoxDecoration(
            border: Border(
              right: showRightBorder
                  ? const BorderSide(color: AppColors.divider)
                  : BorderSide.none,
              bottom: showBottomBorder
                  ? const BorderSide(color: AppColors.divider)
                  : BorderSide.none,
            ),
          ),
          foregroundDecoration: isSelected
              ? BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 1.5),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: numberDecoration,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontFamily: AppText.fontFamily,
                      fontSize: 13,
                      fontWeight: isToday || isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: numberColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              for (final r in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _BookingBar(
                    reservation: r,
                    faded: !inMonth,
                    onTap: () => onOpen(r),
                  ),
                ),
              if (more > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 1),
                  child: Text(
                    '+$more more',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coloured bar with the guest name; hover shows the booking details.
class _BookingBar extends StatelessWidget {
  final Reservation reservation;
  final bool faded;
  final VoidCallback onTap;

  const _BookingBar({
    required this.reservation,
    required this.faded,
    required this.onTap,
  });

  String get _tooltip {
    final r = reservation;
    final times = r.isLegacy
        ? '${DateFormatUtil.short(r.startAt)} → ${DateFormatUtil.short(r.endAt)}'
        : '${DateFormatUtil.shortWithTime(r.startAt)}\n'
              '→ ${DateFormatUtil.shortWithTime(r.endAt)}';
    return [
      r.guestName.isEmpty ? '—' : r.guestName,
      r.unitLine,
      r.stayTypeDisplayName,
      times,
      'Status: ${r.status.isEmpty ? ReservationStatus.reserved : r.status}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final style = StatusStyle.of(r.status);
    final dim = r.isCancelled || faded;
    final radius = BorderRadius.circular(4);

    return Tooltip(
      message: _tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Opacity(
        opacity: dim ? 0.5 : 1,
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: style.tint,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: style.color, width: 3),
                  ),
                ),
                child: Text(
                  r.guestName.isEmpty ? '—' : r.guestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppText.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: style.color,
                    decoration: r.isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop side panel: selected day, other reservations this month, add.
class _DesktopDayPanel extends StatelessWidget {
  final DateTime selectedDay;
  final DateTime focusedMonth;
  final List<Reservation> reservations;
  final ValueChanged<Reservation> onOpen;
  final VoidCallback onAdd;

  const _DesktopDayPanel({
    required this.selectedDay,
    required this.focusedMonth,
    required this.reservations,
    required this.onOpen,
    required this.onAdd,
  });

  static const int _maxOthers = 8;

  @override
  Widget build(BuildContext context) {
    final dayBookings = CalendarLogic.reservationsOn(reservations, selectedDay);
    final dayIds = dayBookings.map((r) => r.id).toSet();
    final others = CalendarLogic.reservationsInMonth(
      reservations,
      focusedMonth,
    ).where((r) => !dayIds.contains(r.id)).toList();
    final shownOthers = others.take(_maxOthers).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selected date + its bookings
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${selectedDay.day}',
                      style: AppText.headerTitle.copyWith(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormatUtil.weekday(selectedDay),
                          style: AppText.cardTitle,
                        ),
                        Text(
                          DateFormatUtil.long(selectedDay),
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                dayBookings.isEmpty
                    ? 'No reservations on this day.'
                    : '${dayBookings.length} reservation'
                          '${dayBookings.length == 1 ? '' : 's'}',
                style: AppText.overline.copyWith(fontWeight: FontWeight.w600),
              ),
              for (final r in dayBookings) ...[
                const SizedBox(height: 10),
                _DayBookingTile(reservation: r, onOpen: () => onOpen(r)),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Other reservations this month
        PanelCard(
          title: 'Other reservations this month',
          subtitle: DateFormatUtil.monthYear(focusedMonth),
          child: others.isEmpty
              ? Text(
                  'No other reservations this month.',
                  style: AppText.bodySecondary.copyWith(
                    color: AppColors.textMuted,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in shownOthers)
                      _OtherReservationRow(
                        reservation: r,
                        onTap: () => onOpen(r),
                      ),
                    if (others.length > shownOthers.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '+${others.length - shownOthers.length} more '
                          'this month',
                          style: AppText.caption,
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          style: CompactButtons.filled(),
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Add New Reservation'),
        ),
      ],
    );
  }
}

/// Booking on the selected day (side panel).
class _DayBookingTile extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onOpen;

  const _DayBookingTile({required this.reservation, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final style = StatusStyle.of(r.status);

    return Opacity(
      opacity: r.isCancelled ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: style.dot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.guestName.isEmpty ? '—' : r.guestName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.valueStrong,
                  ),
                ),
                StatusBadge(status: r.status, tinted: true, fontSize: 10),
              ],
            ),
            const SizedBox(height: 6),
            Text(r.unitLine, style: AppText.caption),
            Text(r.stayLine, style: AppText.caption),
            Text(r.rangeLine, style: AppText.caption),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact row in "Other reservations this month".
class _OtherReservationRow extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onTap;

  const _OtherReservationRow({required this.reservation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final style = StatusStyle.of(r.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: r.isCancelled ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  color: style.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.guestName.isEmpty ? '—' : r.guestName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.value.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${DateFormatUtil.monthDay(r.startAt)} · '
                      '${r.unitDisplayName.isEmpty ? '—' : r.unitDisplayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<Reservation> reservations;
  final List<Reservation> Function(List<Reservation>, DateTime) reservationsOn;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  const _MonthCalendar({
    required this.focusedMonth,
    required this.selectedDay,
    required this.reservations,
    required this.reservationsOn,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  /// All days shown in the grid (Sunday-first, whole weeks).
  List<DateTime> _gridDays() => CalendarLogic.monthGridDays(focusedMonth);

  @override
  Widget build(BuildContext context) {
    final days = _gridDays();
    final today = DateFormatUtil.dateOnly(DateTime.now());
    final weeks = <List<DateTime>>[
      for (var i = 0; i < days.length; i += 7) days.sublist(i, i + 7),
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      shadow: const [
        BoxShadow(
          color: Color(0x14000000),
          offset: Offset(0, 2),
          blurRadius: 12,
        ),
      ],
      child: Column(
        children: [
          // Month header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundIconButton(
                  icon: Icons.chevron_left,
                  tooltip: 'Previous month',
                  onTap: onPrev,
                ),
                Text(
                  DateFormatUtil.monthYear(focusedMonth),
                  style: AppText.cardTitle.copyWith(fontSize: 18, height: 1.5),
                ),
                _RoundIconButton(
                  icon: Icons.chevron_right,
                  tooltip: 'Next month',
                  onTap: onNext,
                ),
              ],
            ),
          ),

          // Weekday labels
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                for (final w in _weekdays)
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: Center(
                        child: Text(
                          w,
                          style: AppText.fieldLabel.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const _InsetDivider(),

          // Day grid
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              children: [
                for (final week in weeks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        for (final day in week)
                          Expanded(
                            child: _DayCell(
                              day: day,
                              inMonth: day.month == focusedMonth.month,
                              isToday: DateFormatUtil.isSameDay(day, today),
                              isSelected: DateFormatUtil.isSameDay(
                                day,
                                selectedDay,
                              ),
                              bookings: reservationsOn(reservations, day),
                              onTap: () => onSelect(day),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const _InsetDivider(),

          // Legend
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 12,
              children: const [
                _LegendItem(status: ReservationStatus.reserved),
                _LegendItem(status: ReservationStatus.checkedIn),
                _LegendItem(status: ReservationStatus.completed),
                _LegendItem(status: ReservationStatus.cancelled),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<Reservation> bookings;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.bookings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor = inMonth ? AppColors.textPrimary : AppColors.textDisabled;
    FontWeight weight = FontWeight.w500;
    BoxDecoration? circle;

    if (isSelected) {
      textColor = Colors.white;
      weight = FontWeight.w700;
      circle = const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      textColor = AppColors.primary;
      weight = FontWeight.w700;
      circle = BoxDecoration(
        color: AppColors.primaryTint,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary),
      );
    }

    final dotColor = bookings.isEmpty
        ? null
        : StatusStyle.of(bookings.first.status).dot;

    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: circle,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontFamily: AppText.fontFamily,
                  fontSize: 14,
                  fontWeight: weight,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor != null && inMonth ? dotColor : null,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String status;

  const _LegendItem({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: StatusStyle.of(status).dot,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: AppText.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 26, color: AppColors.primary),
      ),
    );
  }
}

class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Divider(height: 1, thickness: 1, color: AppColors.divider),
    );
  }
}
