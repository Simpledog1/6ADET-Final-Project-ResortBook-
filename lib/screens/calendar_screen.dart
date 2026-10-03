import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../services/pocketbase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/reservation_cards.dart';
import '../widgets/status_badge.dart';
import 'reservation_details_screen.dart';

/// Reservation Calendar (Figma "Calendar View").
///
/// Month grid with a coloured dot on every day that has a booking
/// (check-in through check-out, inclusive) and a list of the
/// reservations on the selected day underneath.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

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
    final today = DateFormatUtil.dateOnly(DateTime.now());
    _selectedDay = today;
    _focusedMonth = DateTime(today.year, today.month);
    _reservationsFuture = PocketBaseService.getReservations();
  }

  void _reload() {
    setState(() {
      _reservationsFuture = PocketBaseService.getReservations();
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  /// Reservations whose stay covers [day] (inclusive of check-out day).
  List<Reservation> _reservationsOn(List<Reservation> all, DateTime day) {
    return all.where((r) {
      final start = DateFormatUtil.dateOnly(r.checkInDate);
      final end = DateFormatUtil.dateOnly(r.checkOutDate);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList()
      ..sort((a, b) => a.checkInDate.compareTo(b.checkInDate));
  }

  @override
  Widget build(BuildContext context) {
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
                  onSelect: (day) => setState(() {
                    _selectedDay = day;
                    if (day.month != _focusedMonth.month ||
                        day.year != _focusedMonth.year) {
                      _focusedMonth = DateTime(day.year, day.month);
                    }
                  }),
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
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ReservationDetailsScreen(reservation: res),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
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
  List<DateTime> _gridDays() {
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final leading = first.weekday % 7; // Sunday = 0
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    return List.generate(
      totalCells,
      (i) => DateTime(first.year, first.month, 1 - leading + i),
    );
  }

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
                              isSelected:
                                  DateFormatUtil.isSameDay(day, selectedDay),
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
                _LegendItem(status: 'Reserved'),
                _LegendItem(status: 'Checked In'),
                _LegendItem(status: 'Completed'),
                _LegendItem(status: 'Cancelled'),
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
        Text(status, style: AppText.caption.copyWith(
          color: AppColors.textSecondary,
        )),
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
