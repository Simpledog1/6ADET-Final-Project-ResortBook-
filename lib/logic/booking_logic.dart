import '../models/rate.dart';
import '../models/reservation.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';

/// The exact time range a reservation occupies (local time).
class StayWindow {
  final DateTime start;
  final DateTime end;

  /// Nights covered: 0 for same-day stays (e.g. Day Tour),
  /// ≥ 1 for stays that end on a later day (Overnight, Night Tour).
  final int nights;

  const StayWindow({
    required this.start,
    required this.end,
    required this.nights,
  });
}

/// The calculated price of a stay, in Philippine pesos (₱).
class PriceQuote {
  final double rate;
  final PricingBasis basis;

  /// Number of nights for `per_night`, always 1 for `per_stay`.
  final int quantity;
  final double total;

  const PriceQuote({
    required this.rate,
    required this.basis,
    required this.quantity,
    required this.total,
  });
}

/// Pure booking rules (no Flutter, no network) so they can be unit tested.
class BookingLogic {
  BookingLogic._();

  // ── Time windows ───────────────────────────────────────────────────────

  /// Builds the stay window from the selected check-in [date] (only the
  /// year/month/day are used) and the stay type's configured duration
  /// ([StayType.durationMinutes]).
  ///
  /// * The stay starts at [startTime], or at the stay type's default
  ///   check-in time when [startTime] is null.
  /// * It ends after the configured duration. Multi-night stay types
  ///   (`allowMultipleNights`) add one day per extra night.
  /// * With the default start time the result is exactly the stay type's
  ///   check-in → check-out times (e.g. Overnight 2:00 PM → 12:00 PM).
  ///
  /// Returns null when the configuration can't produce a valid range
  /// (e.g. a same-day stay type whose check-out isn't after check-in).
  static StayWindow? computeWindow({
    required StayType stayType,
    required DateTime date,
    int nights = 1,
    ({int hour, int minute})? startTime,
  }) {
    final duration = stayType.durationMinutes;
    if (duration == null) return null;

    final from = startTime ?? stayType.checkIn;
    if (from.hour < 0 || from.hour > 23 || from.minute < 0) return null;
    if (from.minute > 59) return null;

    final int extraNights;
    if (stayType.endsNextDay && stayType.allowMultipleNights) {
      if (nights < 1) return null;
      extraNights = nights - 1;
    } else {
      extraNights = 0;
    }

    // Wall-clock arithmetic with DateTime(y, m, d + n, h, m) so a stay
    // always ends at the same clock time (DST-safe).
    final endTotal = from.hour * 60 + from.minute + duration;
    final endDayOffset = extraNights + endTotal ~/ (24 * 60);
    final endMinute = endTotal % (24 * 60);

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      from.hour,
      from.minute,
    );
    final end = DateTime(
      date.year,
      date.month,
      date.day + endDayOffset,
      endMinute ~/ 60,
      endMinute % 60,
    );

    if (!end.isAfter(start)) return null;
    return StayWindow(
      start: start,
      end: end,
      // Stays that end the next day count their nights (used for per-night
      // pricing); same-day stays count calendar days crossed (usually 0).
      nights: stayType.endsNextDay
          ? extraNights + 1
          : nightsBetween(start, end),
    );
  }

  /// Whole calendar days between two dates (time of day ignored).
  static int nightsBetween(DateTime checkInDate, DateTime checkOutDate) {
    final a = DateTime.utc(
      checkInDate.year,
      checkInDate.month,
      checkInDate.day,
    );
    final b = DateTime.utc(
      checkOutDate.year,
      checkOutDate.month,
      checkOutDate.day,
    );
    return b.difference(a).inDays;
  }

  // ── Conflicts ──────────────────────────────────────────────────────────

  /// `newStart < existingEnd && newEnd > existingStart`.
  /// Touching ranges (one ends exactly when the other starts) don't overlap.
  static bool overlaps(
    DateTime newStart,
    DateTime newEnd,
    DateTime existingStart,
    DateTime existingEnd,
  ) {
    return newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
  }

  /// Existing reservations that block [window] on [unitId].
  ///
  /// Only the same unit is compared, cancelled reservations never block,
  /// and [excludeReservationId] (the one being edited) is ignored.
  /// Legacy reservations without a stay type use their stored start/end.
  static List<Reservation> findConflicts({
    required String unitId,
    required StayWindow window,
    required Iterable<Reservation> existing,
    String? excludeReservationId,
  }) {
    return existing.where((r) {
      if (r.unitId != unitId) return false;
      if (r.isCancelled) return false;
      if (excludeReservationId != null && r.id == excludeReservationId) {
        return false;
      }
      return overlaps(window.start, window.end, r.startAt, r.endAt);
    }).toList();
  }

  // ── Pricing ────────────────────────────────────────────────────────────

  /// The configured rate for [unitTypeId] + [stayTypeId], or null.
  static Rate? findRate({
    required Iterable<Rate> rates,
    required String unitTypeId,
    required String stayTypeId,
  }) {
    if (unitTypeId.isEmpty || stayTypeId.isEmpty) return null;
    for (final rate in rates) {
      if (rate.unitTypeId == unitTypeId && rate.stayTypeId == stayTypeId) {
        return rate;
      }
    }
    return null;
  }

  /// Price for a stay. `per_night` multiplies by the nights (minimum 1);
  /// `per_stay` charges the rate once.
  static PriceQuote quote({
    required Rate rate,
    required StayType stayType,
    required StayWindow window,
  }) {
    final basis = stayType.pricingBasis;
    final quantity = basis == PricingBasis.perNight
        ? (window.nights < 1 ? 1 : window.nights)
        : 1;
    return PriceQuote(
      rate: rate.price,
      basis: basis,
      quantity: quantity,
      total: rate.price * quantity,
    );
  }

  // ── Validation ─────────────────────────────────────────────────────────

  /// Error message for the guest count, or null when it's valid.
  static String? validateGuestCount(int? guestCount, Unit? unit) {
    if (guestCount == null || guestCount < 1) {
      return 'Enter at least 1 guest.';
    }
    if (unit != null && unit.capacity > 0 && guestCount > unit.capacity) {
      return '${unit.name} fits up to ${unit.capacity} '
          'guest${unit.capacity == 1 ? '' : 's'}.';
    }
    return null;
  }
}
