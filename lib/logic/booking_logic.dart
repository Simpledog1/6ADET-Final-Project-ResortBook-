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
  /// year/month/day are used) and the stay type's configured times.
  ///
  /// * Same-day stay types (`endsNextDay == false`) end on [date].
  /// * Stay types that cross midnight end on a later day: after [nights]
  ///   days when `allowMultipleNights` is true, otherwise after 1 day.
  ///
  /// Returns null when the configuration can't produce a valid range
  /// (e.g. a same-day stay type whose check-out isn't after check-in).
  static StayWindow? computeWindow({
    required StayType stayType,
    required DateTime date,
    int nights = 1,
  }) {
    final checkIn = stayType.checkIn;
    final checkOut = stayType.checkOut;

    final int endDayOffset;
    if (!stayType.endsNextDay) {
      endDayOffset = 0;
    } else if (stayType.allowMultipleNights) {
      if (nights < 1) return null;
      endDayOffset = nights;
    } else {
      endDayOffset = 1;
    }

    // DateTime(y, m, d + n) is calendar-day arithmetic (DST-safe).
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      checkIn.hour,
      checkIn.minute,
    );
    final end = DateTime(
      date.year,
      date.month,
      date.day + endDayOffset,
      checkOut.hour,
      checkOut.minute,
    );

    if (!end.isAfter(start)) return null;
    return StayWindow(start: start, end: end, nights: endDayOffset);
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
