import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/logic/booking_logic.dart';
import 'package:final_project/models/rate.dart';
import 'package:final_project/models/reservation.dart';
import 'package:final_project/models/stay_type.dart';
import 'package:final_project/models/unit.dart';

// Same configuration as the default stay types seeded in PocketBase.
const overnight = StayType(
  id: 'st_overnight',
  name: 'Overnight',
  checkInTime: '14:00',
  checkOutTime: '12:00',
  endsNextDay: true,
  allowMultipleNights: true,
  pricingBasis: PricingBasis.perNight,
);
const dayTour = StayType(
  id: 'st_day',
  name: 'Day Tour',
  checkInTime: '08:00',
  checkOutTime: '17:00',
  endsNextDay: false,
  allowMultipleNights: false,
  pricingBasis: PricingBasis.perStay,
);
const nightTour = StayType(
  id: 'st_night',
  name: 'Night Tour',
  checkInTime: '19:00',
  checkOutTime: '06:00',
  endsNextDay: true,
  allowMultipleNights: false,
  pricingBasis: PricingBasis.perStay,
);

const cottage = Unit(
  id: 'unit_a',
  name: 'Cottage 1',
  unitTypeId: 'ut_cottage',
  capacity: 4,
);

Reservation booking({
  String id = 'r1',
  String unitId = 'unit_a',
  required DateTime start,
  required DateTime end,
  String status = 'Reserved',
  String stayTypeId = 'st_overnight',
}) {
  return Reservation(
    id: id,
    guestName: 'Guest $id',
    phone: '',
    email: '',
    unitId: unitId,
    stayTypeId: stayTypeId,
    startAt: start,
    endAt: end,
    status: status,
  );
}

void main() {
  final june15 = DateTime(2026, 6, 15);

  group('computeWindow', () {
    test('Overnight, 1 night: 2:00 PM to 12:00 PM next day', () {
      final w = BookingLogic.computeWindow(stayType: overnight, date: june15)!;
      expect(w.start, DateTime(2026, 6, 15, 14));
      expect(w.end, DateTime(2026, 6, 16, 12));
      expect(w.nights, 1);
    });

    test('Overnight, 3 nights ends 3 days later at 12:00 PM', () {
      final w = BookingLogic.computeWindow(
        stayType: overnight,
        date: june15,
        nights: 3,
      )!;
      expect(w.start, DateTime(2026, 6, 15, 14));
      expect(w.end, DateTime(2026, 6, 18, 12));
      expect(w.nights, 3);
    });

    test('Overnight with 0 nights is invalid', () {
      expect(
        BookingLogic.computeWindow(
          stayType: overnight,
          date: june15,
          nights: 0,
        ),
        isNull,
      );
    });

    test('Overnight crossing a month boundary', () {
      final w = BookingLogic.computeWindow(
        stayType: overnight,
        date: DateTime(2026, 6, 30),
        nights: 2,
      )!;
      expect(w.end, DateTime(2026, 7, 2, 12));
    });

    test('Day Tour stays on the same day: 8:00 AM to 5:00 PM', () {
      final w = BookingLogic.computeWindow(stayType: dayTour, date: june15)!;
      expect(w.start, DateTime(2026, 6, 15, 8));
      expect(w.end, DateTime(2026, 6, 15, 17));
      expect(w.nights, 0);
    });

    test('Night Tour crosses midnight: 7:00 PM to 6:00 AM next day', () {
      final w = BookingLogic.computeWindow(stayType: nightTour, date: june15)!;
      expect(w.start, DateTime(2026, 6, 15, 19));
      expect(w.end, DateTime(2026, 6, 16, 6));
      expect(w.nights, 1);
    });

    test('Night Tour ignores the nights value (single night only)', () {
      final w = BookingLogic.computeWindow(
        stayType: nightTour,
        date: june15,
        nights: 5,
      )!;
      expect(w.end, DateTime(2026, 6, 16, 6));
    });

    test(
      'a same-day stay type whose check-out is before check-in is invalid',
      () {
        const broken = StayType(
          id: 'x',
          name: 'Broken',
          checkInTime: '17:00',
          checkOutTime: '08:00',
          endsNextDay: false,
        );
        expect(
          BookingLogic.computeWindow(stayType: broken, date: june15),
          isNull,
        );
      },
    );
  });

  group('nightsBetween', () {
    test('counts calendar days', () {
      expect(BookingLogic.nightsBetween(june15, DateTime(2026, 6, 18)), 3);
      expect(BookingLogic.nightsBetween(june15, june15), 0);
    });
  });

  group('findConflicts', () {
    final overnightWindow = BookingLogic.computeWindow(
      stayType: overnight,
      date: june15,
    )!;

    test('same unit with overlapping times conflicts', () {
      final existing = [
        booking(
          start: DateTime(2026, 6, 15, 8),
          end: DateTime(2026, 6, 15, 17),
          stayTypeId: 'st_day',
        ), // Day Tour on the same day overlaps 2:00–5:00 PM
      ];
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: overnightWindow,
          existing: existing,
        ),
        hasLength(1),
      );
    });

    test('different units at overlapping times do not conflict', () {
      final existing = [
        booking(
          unitId: 'unit_b',
          start: DateTime(2026, 6, 15, 14),
          end: DateTime(2026, 6, 16, 12),
        ),
      ];
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: overnightWindow,
          existing: existing,
        ),
        isEmpty,
      );
    });

    test('back-to-back on the same unit is allowed', () {
      // Previous booking ends exactly at 2:00 PM when the new one starts.
      final existing = [
        booking(
          start: DateTime(2026, 6, 15, 8),
          end: DateTime(2026, 6, 15, 14),
        ),
        // Next guest starts exactly when the new one ends (12:00 PM June 16).
        booking(
          id: 'r2',
          start: DateTime(2026, 6, 16, 12),
          end: DateTime(2026, 6, 17, 12),
        ),
      ];
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: overnightWindow,
          existing: existing,
        ),
        isEmpty,
      );
    });

    test('Overnight check-out then Day Tour the same day overlaps', () {
      final dayWindow = BookingLogic.computeWindow(
        stayType: dayTour,
        date: DateTime(2026, 6, 16),
      )!; // 8 AM–5 PM June 16, previous Overnight leaves at 12 PM
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: dayWindow,
          existing: [
            booking(
              start: DateTime(2026, 6, 15, 14),
              end: DateTime(2026, 6, 16, 12),
            ),
          ],
        ),
        hasLength(1),
      );
    });

    test('Day Tour then Night Tour on the same day does not overlap', () {
      final nightWindow = BookingLogic.computeWindow(
        stayType: nightTour,
        date: june15,
      )!;
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: nightWindow,
          existing: [
            booking(
              start: DateTime(2026, 6, 15, 8),
              end: DateTime(2026, 6, 15, 17),
              stayTypeId: 'st_day',
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('cancelled reservations never block availability', () {
      final existing = [
        booking(
          start: DateTime(2026, 6, 15, 14),
          end: DateTime(2026, 6, 16, 12),
          status: 'Cancelled',
        ),
      ];
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: overnightWindow,
          existing: existing,
        ),
        isEmpty,
      );
    });

    test('legacy reservation without a stay type uses its stored range', () {
      final existing = [
        booking(
          start: DateTime(2026, 6, 14),
          end: DateTime(2026, 6, 16), // midnight-to-midnight legacy booking
          stayTypeId: '',
        ),
      ];
      expect(existing.first.isLegacy, isTrue);
      expect(existing.first.stayTypeDisplayName, 'Overnight');
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: overnightWindow,
          existing: existing,
        ),
        hasLength(1),
      );
    });

    test('the reservation being edited is ignored', () {
      final existing = [
        booking(
          id: 'self',
          start: DateTime(2026, 6, 15, 14),
          end: DateTime(2026, 6, 16, 12),
        ),
      ];
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: overnightWindow,
          existing: existing,
          excludeReservationId: 'self',
        ),
        isEmpty,
      );
    });
  });

  group('pricing', () {
    const rates = [
      Rate(
        id: 'r1',
        unitTypeId: 'ut_cottage',
        stayTypeId: 'st_overnight',
        price: 2500,
      ),
      Rate(
        id: 'r2',
        unitTypeId: 'ut_cottage',
        stayTypeId: 'st_day',
        price: 800,
      ),
    ];

    test('per_night multiplies by the number of nights', () {
      final rate = BookingLogic.findRate(
        rates: rates,
        unitTypeId: 'ut_cottage',
        stayTypeId: 'st_overnight',
      )!;
      final w = BookingLogic.computeWindow(
        stayType: overnight,
        date: june15,
        nights: 3,
      )!;
      final q = BookingLogic.quote(rate: rate, stayType: overnight, window: w);
      expect(q.quantity, 3);
      expect(q.total, 7500);
      expect(q.basis, PricingBasis.perNight);
    });

    test('per_stay charges the rate once', () {
      final rate = BookingLogic.findRate(
        rates: rates,
        unitTypeId: 'ut_cottage',
        stayTypeId: 'st_day',
      )!;
      final w = BookingLogic.computeWindow(stayType: dayTour, date: june15)!;
      final q = BookingLogic.quote(rate: rate, stayType: dayTour, window: w);
      expect(q.quantity, 1);
      expect(q.total, 800);
    });

    test('missing rate returns null instead of a guessed price', () {
      expect(
        BookingLogic.findRate(
          rates: rates,
          unitTypeId: 'ut_cottage',
          stayTypeId: 'st_night',
        ),
        isNull,
      );
      expect(
        BookingLogic.findRate(
          rates: rates,
          unitTypeId: '',
          stayTypeId: 'st_day',
        ),
        isNull,
      );
    });
  });

  group('guest count', () {
    test('must be at least 1', () {
      expect(BookingLogic.validateGuestCount(null, cottage), isNotNull);
      expect(BookingLogic.validateGuestCount(0, cottage), isNotNull);
    });

    test('must not exceed the unit capacity', () {
      expect(BookingLogic.validateGuestCount(4, cottage), isNull);
      expect(BookingLogic.validateGuestCount(5, cottage), isNotNull);
    });
  });
}
