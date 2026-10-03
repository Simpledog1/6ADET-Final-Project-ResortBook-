import '../models/reservation.dart';

/// Which reservations belong on which calendar day.
///
/// Pure Dart (no Flutter, no network) so it can be unit tested. Used by both
/// the phone and the desktop calendar.
///
/// A reservation belongs on every day its actual time window touches:
/// `startAt < end of day && endAt > start of day`. So:
/// * a Day Tour (8 AM → 5 PM) shows on one day;
/// * an Overnight (2 PM → 12 PM next day) shows on its check-in and its
///   check-out day, and every day in between for multi-night stays;
/// * a Night Tour (7 PM → 6 AM) shows on both dates;
/// * a booking ending exactly at midnight does not show on the next day.
///
/// Cancelled reservations are still listed (so staff can see them), but
/// always after the active ones.
class CalendarLogic {
  CalendarLogic._();

  /// Local midnight at the start of [day].
  static DateTime startOfDay(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  /// Local midnight at the start of the day after [day].
  static DateTime endOfDay(DateTime day) =>
      DateTime(day.year, day.month, day.day + 1);

  /// True when [reservation]'s time window overlaps [day].
  static bool touchesDay(Reservation reservation, DateTime day) =>
      touchesRange(reservation, startOfDay(day), endOfDay(day));

  /// True when [reservation]'s time window overlaps [start, end).
  static bool touchesRange(
    Reservation reservation,
    DateTime start,
    DateTime end,
  ) => reservation.startAt.isBefore(end) && reservation.endAt.isAfter(start);

  /// Active reservations first, then cancelled; each group by start time.
  static int compareForCalendar(Reservation a, Reservation b) {
    if (a.isCancelled != b.isCancelled) return a.isCancelled ? 1 : -1;
    return a.startAt.compareTo(b.startAt);
  }

  /// Reservations on [day], active first, then by start time.
  static List<Reservation> reservationsOn(
    Iterable<Reservation> all,
    DateTime day,
  ) {
    return all.where((r) => touchesDay(r, day)).toList()
      ..sort(compareForCalendar);
  }

  /// Reservations touching any day of [month] (any day of that month can be
  /// passed), active first, then by start time.
  static List<Reservation> reservationsInMonth(
    Iterable<Reservation> all,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return all.where((r) => touchesRange(r, start, end)).toList()
      ..sort(compareForCalendar);
  }

  /// Days shown in a Sunday-first month grid (whole weeks, so it includes
  /// trailing days of the previous month and leading days of the next).
  static List<DateTime> monthGridDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday % 7; // Sunday = 0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    return List.generate(
      totalCells,
      (i) => DateTime(first.year, first.month, 1 - leading + i),
    );
  }
}
