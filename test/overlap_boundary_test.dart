// Boundary cases for the double-booking rule
// `newStart < existingEnd && newEnd > existingStart`.
//
// These test the pure Dart rule used by Add Reservation, Edit and Restore.
// They do not (and cannot) test PocketBase: the rule is not enforced by the
// server in this project, see docs/09-reservations-and-data-integrity.md.

import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/logic/booking_logic.dart';
import 'package:final_project/models/reservation.dart';

Reservation _booking({
  String id = 'r1',
  String unitId = 'unit_a',
  required DateTime start,
  required DateTime end,
  String status = 'Reserved',
}) {
  return Reservation(
    id: id,
    guestName: 'Guest $id',
    phone: '',
    email: '',
    unitId: unitId,
    startAt: start,
    endAt: end,
    status: status,
  );
}

StayWindow _window(DateTime start, DateTime end) =>
    StayWindow(start: start, end: end, nights: 1);

void main() {
  // Existing booking: June 15, 2:00 PM -> June 16, 12:00 PM.
  final existingStart = DateTime(2026, 6, 15, 14);
  final existingEnd = DateTime(2026, 6, 16, 12);

  group('BookingLogic.overlaps boundaries', () {
    test('identical ranges overlap', () {
      expect(
        BookingLogic.overlaps(
          existingStart,
          existingEnd,
          existingStart,
          existingEnd,
        ),
        isTrue,
      );
    });

    test('new booking ends exactly when the existing one starts: allowed', () {
      expect(
        BookingLogic.overlaps(
          DateTime(2026, 6, 14, 14),
          existingStart,
          existingStart,
          existingEnd,
        ),
        isFalse,
      );
    });

    test('new booking starts exactly when the existing one ends: allowed', () {
      expect(
        BookingLogic.overlaps(
          existingEnd,
          DateTime(2026, 6, 17, 12),
          existingStart,
          existingEnd,
        ),
        isFalse,
      );
    });

    test('overlapping by one minute at the start is blocked', () {
      expect(
        BookingLogic.overlaps(
          DateTime(2026, 6, 14, 14),
          DateTime(2026, 6, 15, 14, 1),
          existingStart,
          existingEnd,
        ),
        isTrue,
      );
    });

    test('overlapping by one minute at the end is blocked', () {
      expect(
        BookingLogic.overlaps(
          DateTime(2026, 6, 16, 11, 59),
          DateTime(2026, 6, 17, 12),
          existingStart,
          existingEnd,
        ),
        isTrue,
      );
    });

    test('new booking inside the existing one is blocked', () {
      expect(
        BookingLogic.overlaps(
          DateTime(2026, 6, 15, 18),
          DateTime(2026, 6, 16, 6),
          existingStart,
          existingEnd,
        ),
        isTrue,
      );
    });

    test('new booking that contains the existing one is blocked', () {
      expect(
        BookingLogic.overlaps(
          DateTime(2026, 6, 14),
          DateTime(2026, 6, 18),
          existingStart,
          existingEnd,
        ),
        isTrue,
      );
    });
  });

  group('BookingLogic.findConflicts with several bookings', () {
    final window = _window(existingStart, existingEnd);

    test('only the overlapping booking is returned, not the touching ones', () {
      final conflicts = BookingLogic.findConflicts(
        unitId: 'unit_a',
        window: window,
        existing: [
          // ends exactly when the new window starts: touching
          _booking(
            id: 'before',
            start: DateTime(2026, 6, 14, 14),
            end: existingStart,
          ),
          // overlaps
          _booking(
            id: 'inside',
            start: DateTime(2026, 6, 15, 20),
            end: DateTime(2026, 6, 16, 6),
          ),
          // starts exactly when the new window ends: touching
          _booking(
            id: 'after',
            start: existingEnd,
            end: DateTime(2026, 6, 17, 12),
          ),
        ],
      );
      expect(conflicts.map((r) => r.id), ['inside']);
    });

    test('a cancelled booking with the identical time does not block', () {
      final conflicts = BookingLogic.findConflicts(
        unitId: 'unit_a',
        window: window,
        existing: [
          _booking(start: existingStart, end: existingEnd, status: 'Cancelled'),
        ],
      );
      expect(conflicts, isEmpty);
    });

    test('Completed and Checked In bookings still block', () {
      for (final status in ['Checked In', 'Completed']) {
        final conflicts = BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: window,
          existing: [
            _booking(start: existingStart, end: existingEnd, status: status),
          ],
        );
        expect(conflicts, hasLength(1), reason: status);
      }
    });

    test('the same time on a different unit does not block', () {
      final conflicts = BookingLogic.findConflicts(
        unitId: 'unit_a',
        window: window,
        existing: [
          _booking(unitId: 'unit_b', start: existingStart, end: existingEnd),
        ],
      );
      expect(conflicts, isEmpty);
    });
  });
}
