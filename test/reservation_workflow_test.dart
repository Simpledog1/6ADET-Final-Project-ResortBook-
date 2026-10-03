import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/logic/booking_logic.dart';
import 'package:final_project/logic/reservation_workflow.dart';
import 'package:final_project/models/rate.dart';
import 'package:final_project/models/reservation.dart';
import 'package:final_project/models/stay_type.dart';
import 'package:final_project/models/unit.dart';

// Same stay types as the defaults seeded in PocketBase.
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
  pricingBasis: PricingBasis.perStay,
);
const oldStayType = StayType(
  id: 'st_old',
  name: 'Old Package',
  checkInTime: '09:00',
  checkOutTime: '15:00',
  isActive: false,
);

const cottageA = Unit(
  id: 'unit_a',
  name: 'Cottage A',
  unitTypeId: 'ut_cottage',
  capacity: 4,
);
const cottageB = Unit(
  id: 'unit_b',
  name: 'Cottage B',
  unitTypeId: 'ut_cottage',
  capacity: 6,
);
const closedVilla = Unit(
  id: 'unit_closed',
  name: 'Old Villa',
  unitTypeId: 'ut_villa',
  capacity: 8,
  isActive: false,
);

/// Overnight Nov 10 2:00 PM → Nov 12 12:00 PM on Cottage A (2 nights).
Reservation booking({
  String id = 'r1',
  String status = 'Reserved',
  String unitId = 'unit_a',
  String stayTypeId = 'st_overnight',
  DateTime? start,
  DateTime? end,
  int guestCount = 2,
}) {
  return Reservation(
    id: id,
    guestName: 'Maria Santos',
    phone: '0917 000 0000',
    email: 'maria@example.com',
    guestCount: guestCount,
    unitId: unitId,
    stayTypeId: stayTypeId,
    startAt: start ?? DateTime(2026, 11, 10, 14),
    endAt: end ?? DateTime(2026, 11, 12, 12),
    status: status,
    notes: 'Late arrival',
    unitName: 'Cottage A',
    unitTypeName: 'Cottage',
    stayTypeName: 'Overnight',
    rate: 2500,
    rateBasis: 'per_night',
    quantity: 2,
    totalAmount: 5000,
  );
}

void main() {
  final beforeCheckInDay = DateTime(2026, 11, 9, 23, 59);
  final checkInDayMorning = DateTime(2026, 11, 10, 7); // before 2:00 PM
  final afterCheckInDay = DateTime(2026, 11, 11, 9);

  group('ReservationStatus.normalize', () {
    test('maps stored spellings to the four statuses', () {
      expect(
        ReservationStatus.normalize('Reserved'),
        ReservationStatus.reserved,
      );
      expect(ReservationStatus.normalize(''), ReservationStatus.reserved);
      expect(
        ReservationStatus.normalize('checked_in'),
        ReservationStatus.checkedIn,
      );
      expect(
        ReservationStatus.normalize('Checked Out'),
        ReservationStatus.completed,
      );
      expect(
        ReservationStatus.normalize('Canceled'),
        ReservationStatus.cancelled,
      );
    });

    test('exact values written to PocketBase', () {
      expect(ReservationStatus.all, [
        'Reserved',
        'Checked In',
        'Completed',
        'Cancelled',
      ]);
    });
  });

  group('status transitions', () {
    test('Reserved → Checked In succeeds on the check-in date', () {
      // Any time on the date counts, even before the 2:00 PM check-in.
      expect(
        ReservationWorkflow.statusChangeError(
          booking(),
          ReservationStatus.checkedIn,
          checkInDayMorning,
        ),
        isNull,
      );
    });

    test('Reserved → Checked In succeeds after the check-in date', () {
      expect(
        ReservationWorkflow.canCheckIn(booking(), afterCheckInDay),
        isTrue,
      );
    });

    test('Reserved → Checked In fails before the check-in date', () {
      final error = ReservationWorkflow.statusChangeError(
        booking(),
        ReservationStatus.checkedIn,
        beforeCheckInDay,
      );
      expect(error, contains('November 10, 2026'));
      expect(
        ReservationWorkflow.canCheckIn(booking(), beforeCheckInDay),
        isFalse,
      );
    });

    test('Reserved → Cancelled succeeds (any day)', () {
      expect(
        ReservationWorkflow.canCancel(booking(), beforeCheckInDay),
        isTrue,
      );
      expect(ReservationWorkflow.canCancel(booking(), afterCheckInDay), isTrue);
    });

    test('Checked In → Completed succeeds', () {
      final r = booking(status: ReservationStatus.checkedIn);
      expect(ReservationWorkflow.canComplete(r, afterCheckInDay), isTrue);
    });

    test('Checked In → Cancelled is not part of the approved workflow', () {
      final r = booking(status: ReservationStatus.checkedIn);
      expect(ReservationWorkflow.canCancel(r, afterCheckInDay), isFalse);
    });

    test('Reserved cannot skip to Completed', () {
      expect(
        ReservationWorkflow.canComplete(booking(), afterCheckInDay),
        isFalse,
      );
    });

    test('Completed cannot change to any status', () {
      final r = booking(status: ReservationStatus.completed);
      for (final status in ReservationStatus.all) {
        expect(
          ReservationWorkflow.canChangeStatus(r, status, afterCheckInDay),
          isFalse,
          reason: 'Completed → $status',
        );
      }
    });

    test('Cancelled cannot change status directly', () {
      final r = booking(status: ReservationStatus.cancelled);
      for (final status in ReservationStatus.all) {
        expect(
          ReservationWorkflow.canChangeStatus(r, status, afterCheckInDay),
          isFalse,
          reason: 'Cancelled → $status',
        );
      }
    });

    test('Cancelled → Reserved points to the Restore path', () {
      final r = booking(status: 'Cancelled');
      expect(
        ReservationWorkflow.statusChangeError(
          r,
          ReservationStatus.reserved,
          afterCheckInDay,
        ),
        contains('Restore'),
      );
    });

    test('unknown or unchanged statuses are rejected', () {
      expect(
        ReservationWorkflow.canChangeStatus(
          booking(),
          'No Show',
          afterCheckInDay,
        ),
        isFalse,
      );
      expect(
        ReservationWorkflow.canChangeStatus(
          booking(),
          ReservationStatus.reserved,
          afterCheckInDay,
        ),
        isFalse,
      );
    });

    test('older spellings are normalised first', () {
      final r = booking(status: 'checked_in');
      expect(ReservationWorkflow.canComplete(r, afterCheckInDay), isTrue);
    });
  });

  group('restore', () {
    final cancelled = booking(id: 'cancelled', status: 'Cancelled');

    test('restore succeeds when the slot is free', () {
      final others = [
        // Back-to-back: starts exactly when the cancelled booking ends.
        booking(
          id: 'next',
          start: DateTime(2026, 11, 12, 12),
          end: DateTime(2026, 11, 13, 12),
        ),
        // Same time on another unit.
        booking(id: 'otherUnit', unitId: 'unit_b'),
        // Another cancelled booking in the same slot doesn't block.
        booking(id: 'alsoCancelled', status: 'Cancelled'),
        // The reservation itself is ignored.
        cancelled,
      ];
      expect(ReservationWorkflow.restoreError(cancelled, others), isNull);
    });

    test('restore is refused when another booking now uses the slot', () {
      final others = [
        booking(
          id: 'newer',
          start: DateTime(2026, 11, 11, 8),
          end: DateTime(2026, 11, 11, 17),
        ),
      ];
      expect(
        ReservationWorkflow.restoreConflicts(
          cancelled,
          others,
        ).map((r) => r.id),
        ['newer'],
      );
      expect(
        ReservationWorkflow.restoreError(cancelled, others),
        contains('already booked'),
      );
    });

    test('only cancelled reservations can be restored', () {
      expect(
        ReservationWorkflow.restoreError(booking(), const []),
        contains('Only cancelled'),
      );
    });
  });

  group('edit permissions', () {
    test('Reserved: every field is editable', () {
      final r = booking();
      expect(ReservationWorkflow.editAccess(r), EditAccess.everything);
      expect(
        ReservationWorkflow.editableFields(r),
        ReservationField.values.toSet(),
      );
      expect(ReservationWorkflow.editBlockedReason(r), isNull);
    });

    test('Checked In: guest details and notes only', () {
      final r = booking(status: ReservationStatus.checkedIn);
      expect(ReservationWorkflow.editAccess(r), EditAccess.guestDetailsOnly);
      expect(ReservationWorkflow.editableFields(r), {
        ReservationField.guestName,
        ReservationField.phone,
        ReservationField.email,
        ReservationField.guestCount,
        ReservationField.notes,
      });
    });

    test('Completed: nothing is editable', () {
      final r = booking(status: ReservationStatus.completed);
      expect(ReservationWorkflow.canEdit(r), isFalse);
      expect(ReservationWorkflow.editableFields(r), isEmpty);
      expect(ReservationWorkflow.editBlockedReason(r), isNotNull);
    });

    test('Cancelled: nothing is editable', () {
      final r = booking(status: ReservationStatus.cancelled);
      expect(ReservationWorkflow.canEdit(r), isFalse);
      expect(ReservationWorkflow.editableFields(r), isEmpty);
      expect(ReservationWorkflow.editBlockedReason(r), contains('Restore'));
    });
  });

  group('classifying an edit', () {
    final original = booking();
    final unchanged = ReservationDraft.fromReservation(original);

    test('no changes', () {
      final plan = ReservationWorkflow.planEdit(original, unchanged);
      expect(plan.hasChanges, isFalse);
      expect(plan.isAllowed, isTrue);
      expect(plan.needsAvailabilityCheck, isFalse);
      expect(plan.needsRepricing, isFalse);
    });

    test('guest details only → no re-price, no availability check', () {
      final plan = ReservationWorkflow.planEdit(
        original,
        unchanged.copyWith(
          guestName: 'Maria S. Cruz',
          phone: '0918 111 1111',
          email: 'maria.cruz@example.com',
        ),
      );
      expect(plan.changedFields, {
        ReservationField.guestName,
        ReservationField.phone,
        ReservationField.email,
      });
      expect(plan.needsRepricing, isFalse);
      expect(plan.needsAvailabilityCheck, isFalse);
      expect(plan.needsCapacityCheck, isFalse);
    });

    test('notes only → no re-price, no availability check', () {
      final plan = ReservationWorkflow.planEdit(
        original,
        unchanged.copyWith(notes: 'Needs an extra bed'),
      );
      expect(plan.changedFields, {ReservationField.notes});
      expect(plan.needsRepricing, isFalse);
      expect(plan.needsAvailabilityCheck, isFalse);
    });

    test('guest count only → no re-price, capacity is checked', () {
      final plan = ReservationWorkflow.planEdit(
        original,
        unchanged.copyWith(guestCount: 5),
      );
      expect(plan.needsRepricing, isFalse);
      expect(plan.needsAvailabilityCheck, isFalse);
      expect(plan.needsCapacityCheck, isTrue);
      // Cottage A fits 4.
      expect(
        ReservationWorkflow.capacityError(plan, 5, cottageA),
        contains('up to 4'),
      );
      expect(ReservationWorkflow.capacityError(plan, 4, cottageA), isNull);
    });

    test('unit change → availability check, re-price and capacity', () {
      final plan = ReservationWorkflow.planEdit(
        original,
        unchanged.copyWith(unitId: 'unit_b'),
      );
      expect(plan.unitChanged, isTrue);
      expect(plan.scheduleChanged, isFalse);
      expect(plan.needsAvailabilityCheck, isTrue);
      expect(plan.needsRepricing, isTrue);
      expect(plan.needsCapacityCheck, isTrue);
    });

    test('stay type change → availability check and re-price', () {
      final plan = ReservationWorkflow.planEdit(
        original,
        unchanged.copyWith(
          stayTypeId: 'st_day',
          startAt: DateTime(2026, 11, 10, 8),
          endAt: DateTime(2026, 11, 10, 17),
        ),
      );
      expect(plan.scheduleChanged, isTrue);
      expect(plan.needsAvailabilityCheck, isTrue);
      expect(plan.needsRepricing, isTrue);
    });

    test('date change → availability check and re-price', () {
      final plan = ReservationWorkflow.planEdit(
        original,
        unchanged.copyWith(
          startAt: DateTime(2026, 11, 15, 14),
          endAt: DateTime(2026, 11, 17, 12),
        ),
      );
      expect(plan.changedFields, {ReservationField.dates});
      expect(plan.needsAvailabilityCheck, isTrue);
      expect(plan.needsRepricing, isTrue);
    });

    test('number of nights change → availability check and re-price', () {
      final plan = ReservationWorkflow.planEdit(
        original,
        unchanged.copyWith(endAt: DateTime(2026, 11, 13, 12)),
      );
      expect(plan.scheduleChanged, isTrue);
      expect(plan.needsRepricing, isTrue);
    });

    test('same moment in UTC is not a date change', () {
      final plan = ReservationWorkflow.planEdit(
        original,
        unchanged.copyWith(
          startAt: original.startAt.toUtc(),
          endAt: original.endAt.toUtc(),
        ),
      );
      expect(plan.hasChanges, isFalse);
    });

    test('Checked In: guest edits allowed, schedule edits refused', () {
      final checkedIn = booking(status: ReservationStatus.checkedIn);
      final draft = ReservationDraft.fromReservation(checkedIn);

      final guestEdit = ReservationWorkflow.planEdit(
        checkedIn,
        draft.copyWith(phone: '0918 222 2222', guestCount: 3),
      );
      expect(guestEdit.isAllowed, isTrue);

      final moveEdit = ReservationWorkflow.planEdit(
        checkedIn,
        draft.copyWith(unitId: 'unit_b'),
      );
      expect(moveEdit.isAllowed, isFalse);
      expect(moveEdit.error, contains('guest details and notes'));
    });

    test('Completed and Cancelled edits are refused', () {
      for (final status in ['Completed', 'Cancelled']) {
        final r = booking(status: status);
        final plan = ReservationWorkflow.planEdit(
          r,
          ReservationDraft.fromReservation(r).copyWith(notes: 'x'),
        );
        expect(plan.isAllowed, isFalse, reason: status);
      }
    });
  });

  group('capacity on old reservations', () {
    test('a contact-only edit is not blocked by a lowered capacity', () {
      // Booked for 6 guests; the unit now only fits 4.
      final r = booking(guestCount: 6);
      final plan = ReservationWorkflow.planEdit(
        r,
        ReservationDraft.fromReservation(r).copyWith(phone: '0918 333 3333'),
      );
      expect(plan.needsCapacityCheck, isFalse);
      expect(ReservationWorkflow.capacityError(plan, 6, cottageA), isNull);
    });

    test('changing the unit checks capacity of the new unit', () {
      final r = booking(guestCount: 6);
      final plan = ReservationWorkflow.planEdit(
        r,
        ReservationDraft.fromReservation(r).copyWith(unitId: 'unit_b'),
      );
      expect(ReservationWorkflow.capacityError(plan, 6, cottageB), isNull);
    });
  });

  group('older reservations without a stay type', () {
    final legacy = booking(stayTypeId: '', guestCount: 0);
    final draft = ReservationDraft.fromReservation(legacy);

    test('guest-only edit is allowed (guest count not required)', () {
      final plan = ReservationWorkflow.planEdit(
        legacy,
        draft.copyWith(guestName: 'Maria Santos-Cruz', notes: 'VIP'),
      );
      expect(plan.isAllowed, isTrue);
      expect(plan.needsRepricing, isFalse);
      expect(ReservationWorkflow.capacityError(plan, 0, cottageA), isNull);
    });

    test('schedule edit without a stay type is refused', () {
      final plan = ReservationWorkflow.planEdit(
        legacy,
        draft.copyWith(
          startAt: DateTime(2026, 11, 15),
          endAt: DateTime(2026, 11, 17),
        ),
      );
      expect(plan.isAllowed, isFalse);
      expect(plan.error, contains('Choose a stay type'));
    });

    test('unit change without a stay type is refused', () {
      final plan = ReservationWorkflow.planEdit(
        legacy,
        draft.copyWith(unitId: 'unit_b'),
      );
      expect(plan.isAllowed, isFalse);
    });

    test('choosing a stay type allows the schedule change', () {
      final plan = ReservationWorkflow.planEdit(
        legacy,
        draft.copyWith(
          stayTypeId: 'st_overnight',
          startAt: DateTime(2026, 11, 15, 14),
          endAt: DateTime(2026, 11, 16, 12),
        ),
      );
      expect(plan.isAllowed, isTrue);
      expect(plan.needsRepricing, isTrue);
    });
  });

  group('unit and stay type options', () {
    final units = [cottageA, cottageB, closedVilla];
    final stayTypes = [overnight, dayTour, oldStayType];

    test('new reservations / other bookings only see active items', () {
      expect(ReservationWorkflow.unitOptions(units).map((u) => u.id), [
        'unit_a',
        'unit_b',
      ]);
      expect(ReservationWorkflow.stayTypeOptions(stayTypes).map((s) => s.id), [
        'st_overnight',
        'st_day',
      ]);
    });

    test(
      "the reservation's own inactive unit / stay type stays selectable",
      () {
        expect(
          ReservationWorkflow.unitOptions(
            units,
            currentUnitId: 'unit_closed',
          ).map((u) => u.id),
          ['unit_a', 'unit_b', 'unit_closed'],
        );
        expect(
          ReservationWorkflow.stayTypeOptions(
            stayTypes,
            currentStayTypeId: 'st_old',
          ).map((s) => s.id),
          ['st_overnight', 'st_day', 'st_old'],
        );
      },
    );

    test('keeping the current inactive selection is allowed', () {
      final r = booking(unitId: 'unit_closed', stayTypeId: 'st_old');
      expect(
        ReservationWorkflow.selectionError(
          original: r,
          unit: closedVilla,
          stayType: oldStayType,
        ),
        isNull,
      );
    });

    test('switching to a different inactive item is refused', () {
      final r = booking();
      expect(
        ReservationWorkflow.selectionError(original: r, unit: closedVilla),
        contains('inactive'),
      );
      expect(
        ReservationWorkflow.selectionError(original: r, stayType: oldStayType),
        contains('inactive'),
      );
      expect(
        ReservationWorkflow.selectionError(
          original: r,
          unit: cottageB,
          stayType: dayTour,
        ),
        isNull,
      );
    });
  });

  group('update body', () {
    final original = booking();
    final unchanged = ReservationDraft.fromReservation(original);

    test('guest-only edit sends only the changed guest fields', () {
      final draft = unchanged.copyWith(phone: '0918 444 4444', notes: 'Gate 2');
      final plan = ReservationWorkflow.planEdit(original, draft);
      final body = ReservationWorkflow.buildUpdateBody(
        plan: plan,
        draft: draft,
      );
      expect(body, {'phone': '0918 444 4444', 'notes': 'Gate 2'});
    });

    test('unchanged schedule keeps start/end and pricing snapshots', () {
      final draft = unchanged.copyWith(guestCount: 3);
      final plan = ReservationWorkflow.planEdit(original, draft);
      final body = ReservationWorkflow.buildUpdateBody(
        plan: plan,
        draft: draft,
      );
      expect(body, {'guestCount': 3});
      for (final key in [
        'startAt',
        'endAt',
        'unit',
        'stayType',
        'unitName',
        'unitTypeName',
        'stayTypeName',
        'rate',
        'rateBasis',
        'quantity',
        'totalAmount',
        'status',
      ]) {
        expect(body.containsKey(key), isFalse, reason: key);
      }
    });

    test('moved booking re-prices with the current rate and new snapshots', () {
      // Move to Cottage B for 3 nights; the cottage rate is now ₱2,800.
      final window = BookingLogic.computeWindow(
        stayType: overnight,
        date: DateTime(2026, 11, 15),
        nights: 3,
      )!;
      const rate = Rate(
        id: 'rate1',
        unitTypeId: 'ut_cottage',
        stayTypeId: 'st_overnight',
        price: 2800,
      );
      final quote = BookingLogic.quote(
        rate: rate,
        stayType: overnight,
        window: window,
      );
      final draft = unchanged.copyWith(
        unitId: 'unit_b',
        startAt: window.start,
        endAt: window.end,
      );
      final plan = ReservationWorkflow.planEdit(original, draft);
      final body = ReservationWorkflow.buildUpdateBody(
        plan: plan,
        draft: draft,
        unit: cottageB,
        stayType: overnight,
        quote: quote,
      );

      expect(body['unit'], 'unit_b');
      expect(body['stayType'], 'st_overnight');
      expect(body['startAt'], window.start.toUtc().toIso8601String());
      expect(body['endAt'], window.end.toUtc().toIso8601String());
      expect(body['unitName'], 'Cottage B');
      expect(body['stayTypeName'], 'Overnight');
      expect(body['rate'], 2800);
      expect(body['rateBasis'], 'per_night');
      expect(body['quantity'], 3);
      expect(body['totalAmount'], 8400);
      expect(body.containsKey('status'), isFalse);
      expect(body.containsKey('guestName'), isFalse); // unchanged
    });

    test('moved booking without a quote is a programming error', () {
      final draft = unchanged.copyWith(unitId: 'unit_b');
      final plan = ReservationWorkflow.planEdit(original, draft);
      expect(
        () => ReservationWorkflow.buildUpdateBody(plan: plan, draft: draft),
        throwsArgumentError,
      );
    });

    test('refused edits cannot build an update', () {
      final r = booking(status: 'Completed');
      final draft = ReservationDraft.fromReservation(r).copyWith(notes: 'x');
      final plan = ReservationWorkflow.planEdit(r, draft);
      expect(
        () => ReservationWorkflow.buildUpdateBody(plan: plan, draft: draft),
        throwsArgumentError,
      );
    });
  });
}
