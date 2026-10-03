import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/logic/calendar_logic.dart';
import 'package:final_project/models/reservation.dart';

Reservation booking(
  String id, {
  required DateTime start,
  required DateTime end,
  String status = 'Reserved',
  String stayTypeId = 'st',
}) {
  return Reservation(
    id: id,
    guestName: 'Guest $id',
    phone: '',
    email: '',
    unitId: 'unit_a',
    stayTypeId: stayTypeId,
    startAt: start,
    endAt: end,
    status: status,
  );
}

/// Ids of the reservations shown on [day].
List<String> idsOn(List<Reservation> all, DateTime day) =>
    CalendarLogic.reservationsOn(all, day).map((r) => r.id).toList();

void main() {
  final nov9 = DateTime(2026, 11, 9);
  final nov10 = DateTime(2026, 11, 10);
  final nov11 = DateTime(2026, 11, 11);
  final nov12 = DateTime(2026, 11, 12);
  final nov13 = DateTime(2026, 11, 13);

  group('reservationsOn', () {
    test('Day Tour shows only on its own day', () {
      final all = [
        booking(
          'day',
          start: DateTime(2026, 11, 10, 8),
          end: DateTime(2026, 11, 10, 17),
        ),
      ];
      expect(idsOn(all, nov9), isEmpty);
      expect(idsOn(all, nov10), ['day']);
      expect(idsOn(all, nov11), isEmpty);
    });

    test('Overnight (one night) shows on check-in and check-out days', () {
      final all = [
        booking(
          'one',
          start: DateTime(2026, 11, 10, 14),
          end: DateTime(2026, 11, 11, 12),
        ),
      ];
      expect(idsOn(all, nov9), isEmpty);
      expect(idsOn(all, nov10), ['one']);
      expect(idsOn(all, nov11), ['one']);
      expect(idsOn(all, nov12), isEmpty);
    });

    test('Overnight (multiple nights) shows on every day of the stay', () {
      final all = [
        booking(
          'multi',
          start: DateTime(2026, 11, 10, 14),
          end: DateTime(2026, 11, 13, 12),
        ),
      ];
      expect(idsOn(all, nov10), ['multi']);
      expect(idsOn(all, nov11), ['multi']);
      expect(idsOn(all, nov12), ['multi']);
      expect(idsOn(all, nov13), ['multi']);
      expect(idsOn(all, DateTime(2026, 11, 14)), isEmpty);
    });

    test('Night Tour crossing midnight shows on both dates', () {
      final all = [
        booking(
          'night',
          start: DateTime(2026, 11, 11, 19),
          end: DateTime(2026, 11, 12, 6),
        ),
      ];
      expect(idsOn(all, nov10), isEmpty);
      expect(idsOn(all, nov11), ['night']);
      expect(idsOn(all, nov12), ['night']);
      expect(idsOn(all, nov13), isEmpty);
    });

    test(
      'booking ending exactly at midnight does not show on the next day',
      () {
        final all = [
          booking(
            'midnight',
            start: DateTime(2026, 11, 10, 18),
            end: DateTime(2026, 11, 11),
          ),
        ];
        expect(idsOn(all, nov10), ['midnight']);
        expect(idsOn(all, nov11), isEmpty);
      },
    );

    test('booking starting exactly at midnight shows only from that day', () {
      final all = [
        booking(
          'early',
          start: DateTime(2026, 11, 11),
          end: DateTime(2026, 11, 11, 6),
        ),
      ];
      expect(idsOn(all, nov10), isEmpty);
      expect(idsOn(all, nov11), ['early']);
    });

    test('cancelled booking is still listed on its days', () {
      final all = [
        booking(
          'cancelled',
          start: DateTime(2026, 11, 10, 8),
          end: DateTime(2026, 11, 10, 17),
          status: 'Cancelled',
        ),
      ];
      expect(idsOn(all, nov10), ['cancelled']);
    });

    test('older reservation without a stay type uses its saved dates', () {
      final all = [
        booking(
          'legacy',
          start: DateTime(2026, 11, 10, 8),
          end: DateTime(2026, 11, 12, 8),
          stayTypeId: '',
        ),
      ];
      expect(all.first.isLegacy, isTrue);
      expect(idsOn(all, nov9), isEmpty);
      expect(idsOn(all, nov10), ['legacy']);
      expect(idsOn(all, nov11), ['legacy']);
      expect(idsOn(all, nov12), ['legacy']);
      expect(idsOn(all, nov13), isEmpty);
    });

    test('active bookings come before cancelled ones, then by start time', () {
      final all = [
        booking(
          'cancelledEarly',
          start: DateTime(2026, 11, 10, 7),
          end: DateTime(2026, 11, 10, 9),
          status: 'Cancelled',
        ),
        booking(
          'late',
          start: DateTime(2026, 11, 10, 19),
          end: DateTime(2026, 11, 11, 6),
        ),
        booking(
          'early',
          start: DateTime(2026, 11, 10, 8),
          end: DateTime(2026, 11, 10, 17),
        ),
        booking(
          'canceledLate',
          start: DateTime(2026, 11, 10, 20),
          end: DateTime(2026, 11, 10, 22),
          status: 'canceled',
        ),
      ];
      expect(idsOn(all, nov10), [
        'early',
        'late',
        'cancelledEarly',
        'canceledLate',
      ]);
    });

    test('back-to-back bookings both show on the changeover day', () {
      final all = [
        booking(
          'first',
          start: DateTime(2026, 11, 10, 14),
          end: DateTime(2026, 11, 11, 12),
        ),
        booking(
          'second',
          start: DateTime(2026, 11, 11, 14),
          end: DateTime(2026, 11, 12, 12),
        ),
      ];
      expect(idsOn(all, nov11), ['first', 'second']);
    });
  });

  group('reservationsInMonth', () {
    test('includes stays that start or end in the month', () {
      final all = [
        booking(
          'octToNov',
          start: DateTime(2026, 10, 31, 14),
          end: DateTime(2026, 11, 1, 12),
        ),
        booking(
          'inNov',
          start: DateTime(2026, 11, 10, 8),
          end: DateTime(2026, 11, 10, 17),
        ),
        booking(
          'novToDec',
          start: DateTime(2026, 11, 30, 19),
          end: DateTime(2026, 12, 1, 6),
        ),
        booking(
          'december',
          start: DateTime(2026, 12, 5, 8),
          end: DateTime(2026, 12, 5, 17),
        ),
        booking(
          'endsAtNovStart',
          start: DateTime(2026, 10, 31, 18),
          end: DateTime(2026, 11, 1),
        ),
      ];
      final ids = CalendarLogic.reservationsInMonth(
        all,
        nov10,
      ).map((r) => r.id).toList();
      expect(ids, ['octToNov', 'inNov', 'novToDec']);
    });
  });

  group('monthGridDays', () {
    test('November 2026 grid is Sunday-first whole weeks', () {
      final days = CalendarLogic.monthGridDays(DateTime(2026, 11));
      expect(days.length % 7, 0);
      expect(days.first.weekday, DateTime.sunday);
      expect(days.first, DateTime(2026, 11, 1)); // Nov 1, 2026 is a Sunday
      expect(days.where((d) => d.month == 11).length, 30);
    });

    test('a month starting mid-week includes previous-month days', () {
      final days = CalendarLogic.monthGridDays(DateTime(2026, 10));
      expect(days.first, DateTime(2026, 9, 27)); // Oct 1, 2026 is a Thursday
      expect(days.where((d) => d.month == 10).length, 31);
    });
  });
}
