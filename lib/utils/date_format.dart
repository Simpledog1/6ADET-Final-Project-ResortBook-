/// Small date helpers so the UI can show Figma-style dates
/// ("Jun 15, 2025" / "June 15, 2025") without adding the intl package.
class DateFormatUtil {
  DateFormatUtil._();

  static const List<String> _monthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _monthsLong = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdaysLong = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// "Saturday"
  static String weekday(DateTime d) => _weekdaysLong[d.toLocal().weekday - 1];

  /// "Sat"
  static String weekdayShort(DateTime d) => weekday(d).substring(0, 3);

  /// "Saturday, October 3, 2026"
  static String fullDate(DateTime d) => '${weekday(d)}, ${long(d)}';

  /// "Jun 15, 2025"
  static String short(DateTime d) {
    final l = d.toLocal();
    return '${_monthsShort[l.month - 1]} ${l.day}, ${l.year}';
  }

  /// "June 15, 2025"
  static String long(DateTime d) {
    final l = d.toLocal();
    return '${_monthsLong[l.month - 1]} ${l.day}, ${l.year}';
  }

  /// "Jun 15"
  static String monthDay(DateTime d) {
    final l = d.toLocal();
    return '${_monthsShort[l.month - 1]} ${l.day}';
  }

  /// "June 2025"
  static String monthYear(DateTime d) {
    return '${_monthsLong[d.month - 1]} ${d.year}';
  }

  /// Strips the time component (local date only).
  static DateTime dateOnly(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Number of nights between check-in and check-out.
  static int nights(DateTime checkIn, DateTime checkOut) {
    final n = dateOnly(checkOut).difference(dateOnly(checkIn)).inDays;
    return n < 0 ? 0 : n;
  }

  /// "2:00 PM"
  static String time(DateTime d) {
    final l = d.toLocal();
    return _formatTime(l.hour, l.minute);
  }

  /// "14:00" (stay type setting) → "2:00 PM". Returns the input if invalid.
  static String timeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    return _formatTime(h, m);
  }

  /// "Jun 15, 2025 · 2:00 PM"
  static String shortWithTime(DateTime d) => '${short(d)} · ${time(d)}';

  /// "Jun 15, 2:00 PM"
  static String monthDayTime(DateTime d) => '${monthDay(d)}, ${time(d)}';

  /// Compact stay range:
  /// * same day → "Jun 15 · 8:00 AM – 5:00 PM"
  /// * multi-day → "Jun 15, 2:00 PM → Jun 16, 12:00 PM"
  /// * [datesOnly] (legacy bookings without times) → "Jun 15 → Jun 18, 2025"
  static String stayRange(
    DateTime start,
    DateTime end, {
    bool datesOnly = false,
  }) {
    if (datesOnly) return '${monthDay(start)} → ${short(end)}';
    if (isSameDay(start.toLocal(), end.toLocal())) {
      return '${monthDay(start)} · ${time(start)} – ${time(end)}';
    }
    return '${monthDayTime(start)} → ${monthDayTime(end)}';
  }

  static String _formatTime(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m ${hour < 12 ? 'AM' : 'PM'}';
  }
}
