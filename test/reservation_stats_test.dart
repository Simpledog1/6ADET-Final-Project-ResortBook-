import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/logic/reservation_stats.dart';
import 'package:final_project/models/reservation.dart';

Reservation booking(
  String id, {
  String guest = '',
  String unitId = 'unit_a',
  required DateTime start,
  required DateTime end,
  String status = 'Reserved',
  DateTime? created,
}) {
  return Reservation(
    id: id,
    guestName: guest.isEmpty ? 'Guest $id' : guest,
    phone: '',
    email: '',
    unitId: unitId,
    stayTypeId: 'st',
    startAt: start,
    endAt: end,
    status: status,
    createdAt: created,
  );
}

List<String> ids(Iterable<Reservation> list) => list.map((r) => r.id).toList();

void main() {
  // "Now" for the dashboard tests: Nov 11, 2026, 10:00 AM.
  final now = DateTime(2026, 11, 11, 10);

  group('statusGroup / statusCounts', () {
    test('normalises different spellings', () {
      expect(
        ReservationStats.statusGroup('Reserved'),
        ReservationStatusFilter.reserved,
      );
      expect(
        ReservationStats.statusGroup(''),
        ReservationStatusFilter.reserved,
      );
      expect(
        ReservationStats.statusGroup('Checked In'),
        ReservationStatusFilter.checkedIn,
      );
      expect(
        ReservationStats.statusGroup('checked_in'),
        ReservationStatusFilter.checkedIn,
      );
      expect(
        ReservationStats.statusGroup('Completed'),
        ReservationStatusFilter.completed,
      );
      expect(
        ReservationStats.statusGroup('Checked-Out'),
        ReservationStatusFilter.completed,
      );
      expect(
        ReservationStats.statusGroup('Cancelled'),
        ReservationStatusFilter.cancelled,
      );
      expect(
        ReservationStats.statusGroup('canceled'),
        ReservationStatusFilter.cancelled,
      );
    });

    test('counts every reservation once plus its status group', () {
      final d = DateTime(2026, 11, 10);
      final list = [
        booking('a', start: d, end: d),
        booking('b', start: d, end: d),
        booking('c', start: d, end: d, status: 'Checked In'),
        booking('d', start: d, end: d, status: 'Cancelled'),
      ];
      final counts = ReservationStats.statusCounts(list);
      expect(counts[ReservationStatusFilter.all], 4);
      expect(counts[ReservationStatusFilter.reserved], 2);
      expect(counts[ReservationStatusFilter.checkedIn], 1);
      expect(counts[ReservationStatusFilter.completed], 0);
      expect(counts[ReservationStatusFilter.cancelled], 1);
      expect(
        ReservationStats.matchesStatus(
          list[3],
          ReservationStatusFilter.cancelled,
        ),
        isTrue,
      );
      expect(
        ReservationStats.matchesStatus(list[3], ReservationStatusFilter.all),
        isTrue,
      );
    });
  });

  group('search', () {
    test('matches guest names ignoring case; empty query keeps all', () {
      final d = DateTime(2026, 11, 10);
      final list = [
        booking('a', guest: 'Maria Santos', start: d, end: d),
        booking('b', guest: 'Juan dela Cruz', start: d, end: d),
      ];
      expect(ids(ReservationStats.search(list, 'maria')), ['a']);
      expect(ids(ReservationStats.search(list, '  CRUZ ')), ['b']);
      expect(ids(ReservationStats.search(list, '')), ['a', 'b']);
    });
  });

  group('dashboard numbers', () {
    final list = [
      // Staying now (Overnight Nov 10 → 12).
      booking(
        'staying',
        unitId: 'cottage_a',
        start: DateTime(2026, 11, 10, 14),
        end: DateTime(2026, 11, 12, 12),
      ),
      // Day Tour in progress on another unit.
      booking(
        'dayTour',
        unitId: 'cottage_b',
        start: DateTime(2026, 11, 11, 8),
        end: DateTime(2026, 11, 11, 17),
      ),
      // Second booking on cottage_b later today (not started yet).
      booking(
        'tonight',
        unitId: 'cottage_b',
        start: DateTime(2026, 11, 11, 19),
        end: DateTime(2026, 11, 12, 6),
      ),
      // Cancelled booking in progress: must not count.
      booking(
        'cancelled',
        unitId: 'villa',
        start: DateTime(2026, 11, 11, 8),
        end: DateTime(2026, 11, 11, 17),
        status: 'Cancelled',
      ),
      // Arrives in 6 days.
      booking(
        'nextWeek',
        start: DateTime(2026, 11, 17, 14),
        end: DateTime(2026, 11, 18, 12),
      ),
      // Arrives in exactly 8 days (outside the 7-day window).
      booking(
        'later',
        start: DateTime(2026, 11, 19, 10),
        end: DateTime(2026, 11, 19, 17),
      ),
      // Already finished this month.
      booking(
        'finished',
        start: DateTime(2026, 11, 2, 8),
        end: DateTime(2026, 11, 2, 17),
      ),
      // Previous month.
      booking(
        'october',
        start: DateTime(2026, 10, 31, 14),
        end: DateTime(2026, 11, 1, 12),
      ),
      // Ends exactly now: no longer staying.
      booking(
        'endsNow',
        unitId: 'villa',
        start: DateTime(2026, 11, 10, 22),
        end: DateTime(2026, 11, 11, 10),
      ),
    ];

    test('reservations this month counts non-cancelled check-ins in month', () {
      // staying, dayTour, tonight, nextWeek, later, finished, endsNow
      expect(ReservationStats.reservationsThisMonth(list, now), 7);
    });

    test('staying now excludes cancelled, future and ended bookings', () {
      expect(
        ids(ReservationStats.stayingNow(list, now)),
        unorderedEquals(['staying', 'dayTour']),
      );
    });

    test('a booking starting exactly now counts as staying', () {
      final startsNow = [
        booking('x', start: now, end: now.add(const Duration(hours: 2))),
      ];
      expect(ids(ReservationStats.stayingNow(startsNow, now)), ['x']);
    });

    test('arriving within 7 days, soonest first', () {
      expect(ids(ReservationStats.arrivingWithin(list, now)), [
        'tonight',
        'nextWeek',
      ]);
    });

    test('units occupied now counts distinct units', () {
      final withDuplicate = [
        ...list,
        // Another active booking on cottage_a (data overlap): still 1 unit.
        booking(
          'dup',
          unitId: 'cottage_a',
          start: DateTime(2026, 11, 11, 9),
          end: DateTime(2026, 11, 11, 11),
        ),
      ];
      expect(ReservationStats.unitsOccupiedNow(list, now), 2);
      expect(ReservationStats.unitsOccupiedNow(withDuplicate, now), 2);
    });

    test('upcoming = not cancelled and not ended, soonest first', () {
      expect(ids(ReservationStats.upcoming(list, now)), [
        'staying',
        'dayTour',
        'tonight',
      ]);
      expect(ReservationStats.upcoming(list, now, limit: 10).length, 5);
    });
  });

  group('Completed reservations', () {
    // Checked out early: the booked end time hasn't passed yet.
    final list = [
      booking(
        'leftEarly',
        unitId: 'cottage_a',
        start: DateTime(2026, 11, 10, 14),
        end: DateTime(2026, 11, 12, 12),
        status: 'Completed',
      ),
      booking(
        'checkedIn',
        unitId: 'cottage_b',
        start: DateTime(2026, 11, 10, 14),
        end: DateTime(2026, 11, 12, 12),
        status: 'Checked In',
      ),
      booking(
        'cancelled',
        unitId: 'villa',
        start: DateTime(2026, 11, 11, 8),
        end: DateTime(2026, 11, 11, 17),
        status: 'Cancelled',
      ),
    ];

    test('are not staying now', () {
      expect(ids(ReservationStats.stayingNow(list, now)), ['checkedIn']);
    });

    test('do not occupy a unit now', () {
      expect(ReservationStats.unitsOccupiedNow(list, now), 1);
    });

    test('are not upcoming', () {
      expect(ids(ReservationStats.upcoming(list, now)), ['checkedIn']);
    });

    test('still count as reservations this month', () {
      expect(ReservationStats.reservationsThisMonth(list, now), 2);
    });
  });

  group('recentlyAdded', () {
    test('newest created first, skips missing timestamps, max 5', () {
      final d = DateTime(2026, 11, 10);
      final list = [
        for (var i = 1; i <= 6; i++)
          booking('r$i', start: d, end: d, created: DateTime(2026, 10, i)),
        booking('noCreated', start: d, end: d),
      ];
      expect(ids(ReservationStats.recentlyAdded(list)), [
        'r6',
        'r5',
        'r4',
        'r3',
        'r2',
      ]);
    });
  });

  group('sorted', () {
    final list = [
      booking(
        'b',
        guest: 'bea',
        start: DateTime(2026, 11, 12, 8),
        end: DateTime(2026, 11, 12, 17),
      ),
      booking(
        'a',
        guest: 'Ana',
        start: DateTime(2026, 11, 14, 14),
        end: DateTime(2026, 11, 15, 12),
      ),
      booking(
        'c',
        guest: 'Carlo',
        start: DateTime(2026, 11, 10, 14),
        end: DateTime(2026, 11, 13, 12),
      ),
    ];

    test('by guest name, case-insensitive', () {
      expect(ids(ReservationStats.sorted(list, ReservationSortField.guest)), [
        'a',
        'b',
        'c',
      ]);
      expect(
        ids(
          ReservationStats.sorted(
            list,
            ReservationSortField.guest,
            ascending: false,
          ),
        ),
        ['c', 'b', 'a'],
      );
    });

    test('by check-in and check-out', () {
      expect(ids(ReservationStats.sorted(list, ReservationSortField.checkIn)), [
        'c',
        'b',
        'a',
      ]);
      expect(
        ids(ReservationStats.sorted(list, ReservationSortField.checkOut)),
        ['b', 'c', 'a'],
      );
      expect(
        ids(
          ReservationStats.sorted(
            list,
            ReservationSortField.checkOut,
            ascending: false,
          ),
        ),
        ['a', 'c', 'b'],
      );
    });

    test('ties are broken by check-in so the order is stable', () {
      final same = [
        booking(
          'late',
          guest: 'Sam',
          start: DateTime(2026, 11, 20),
          end: DateTime(2026, 11, 21),
        ),
        booking(
          'early',
          guest: 'sam',
          start: DateTime(2026, 11, 10),
          end: DateTime(2026, 11, 11),
        ),
      ];
      expect(ids(ReservationStats.sorted(same, ReservationSortField.guest)), [
        'early',
        'late',
      ]);
    });

    test('does not change the original list', () {
      ReservationStats.sorted(list, ReservationSortField.guest);
      expect(ids(list), ['b', 'a', 'c']);
    });
  });

  group('pagination', () {
    final items = List.generate(45, (i) => i);

    test('page count', () {
      expect(ReservationStats.pageCount(0), 1);
      expect(ReservationStats.pageCount(20), 1);
      expect(ReservationStats.pageCount(21), 2);
      expect(ReservationStats.pageCount(45), 3);
    });

    test('pages of 20 items', () {
      expect(ReservationStats.pageOf(items, 0), List.generate(20, (i) => i));
      expect(ReservationStats.pageOf(items, 2), [40, 41, 42, 43, 44]);
    });

    test('out-of-range pages are clamped', () {
      expect(ReservationStats.pageOf(items, 9).first, 40);
      expect(ReservationStats.pageOf(items, -1).first, 0);
      expect(ReservationStats.clampPage(5, 45), 2);
      expect(ReservationStats.pageOf(<int>[], 0), isEmpty);
    });

    test('range label', () {
      expect(
        ReservationStats.rangeLabel(0, 45),
        'Showing 1–20 of 45 reservations',
      );
      expect(
        ReservationStats.rangeLabel(2, 45),
        'Showing 41–45 of 45 reservations',
      );
      expect(ReservationStats.rangeLabel(0, 0), 'No reservations');
    });
  });
}
