// Owner-configured stay durations: how long a stay type lasts comes from
// its settings in Manage Resort, not from hard-coded values.

import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/logic/booking_logic.dart';
import 'package:final_project/logic/config_rules.dart';
import 'package:final_project/logic/reservation_workflow.dart';
import 'package:final_project/models/rate.dart';
import 'package:final_project/models/reservation.dart';
import 'package:final_project/models/stay_type.dart';
import 'package:final_project/models/unit.dart';
import 'package:final_project/models/unit_type.dart';
import 'package:final_project/utils/date_format.dart';

// One resort: Day Tour = 8 hours from 8:00 AM.
const dayTour8h = StayType(
  id: 'st_day',
  name: 'Day Tour',
  checkInTime: '08:00',
  checkOutTime: '16:00',
);

// The same stay type after the owner changes it to 10 hours.
const dayTour10h = StayType(
  id: 'st_day',
  name: 'Day Tour',
  checkInTime: '08:00',
  checkOutTime: '18:00',
);

// Overnight 2:00 PM → 12:00 PM next day (22 hours), multi-night.
const overnight = StayType(
  id: 'st_overnight',
  name: 'Overnight',
  checkInTime: '14:00',
  checkOutTime: '12:00',
  endsNextDay: true,
  allowMultipleNights: true,
  pricingBasis: PricingBasis.perNight,
);

// Another resort's own stay types.
const overnight14h = StayType(
  id: 'st_overnight_b',
  name: 'Overnight',
  checkInTime: '20:00',
  checkOutTime: '10:00',
  endsNextDay: true,
);
const morning5h = StayType(
  id: 'st_morning',
  name: 'Morning',
  checkInTime: '07:00',
  checkOutTime: '12:00',
);

Reservation saved({
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
    stayTypeId: 'st_day',
    startAt: start,
    endAt: end,
    status: status,
  );
}

void main() {
  final june15 = DateTime(2026, 6, 15);

  group('StayType.durationMinutes', () {
    test('comes from the configured times', () {
      expect(dayTour8h.durationMinutes, 8 * 60);
      expect(dayTour10h.durationMinutes, 10 * 60);
      expect(overnight.durationMinutes, 22 * 60);
      expect(overnight14h.durationMinutes, 14 * 60);
      expect(morning5h.durationMinutes, 5 * 60);
    });

    test('is null when the times cannot make a stay', () {
      const broken = StayType(
        id: 'x',
        name: 'Broken',
        checkInTime: '17:00',
        checkOutTime: '08:00',
      );
      expect(broken.durationMinutes, isNull);
    });
  });

  group('reservation end time uses the configured duration', () {
    test('Day Tour = 8 hours: 8:00 AM start ends at 4:00 PM', () {
      final w = BookingLogic.computeWindow(stayType: dayTour8h, date: june15)!;
      expect(w.start, DateTime(2026, 6, 15, 8));
      expect(w.end, DateTime(2026, 6, 15, 16));
      expect(w.nights, 0);
    });

    test(
      'after the owner changes it to 10 hours, new stays end at 6:00 PM',
      () {
        final w = BookingLogic.computeWindow(
          stayType: dayTour10h,
          date: june15,
        )!;
        expect(w.end, DateTime(2026, 6, 15, 18));
      },
    );

    test('another resort: Overnight 14 hours, Morning 5 hours', () {
      final night = BookingLogic.computeWindow(
        stayType: overnight14h,
        date: june15,
      )!;
      expect(night.start, DateTime(2026, 6, 15, 20));
      expect(night.end, DateTime(2026, 6, 16, 10));
      expect(night.nights, 1);

      final am = BookingLogic.computeWindow(stayType: morning5h, date: june15)!;
      expect(am.start, DateTime(2026, 6, 15, 7));
      expect(am.end, DateTime(2026, 6, 15, 12));
    });

    test('a different start time keeps the same duration', () {
      final w = BookingLogic.computeWindow(
        stayType: dayTour8h,
        date: june15,
        startTime: (hour: 10, minute: 30),
      )!;
      expect(w.start, DateTime(2026, 6, 15, 10, 30));
      expect(w.end, DateTime(2026, 6, 15, 18, 30));
    });

    test('a late start can end after midnight', () {
      final w = BookingLogic.computeWindow(
        stayType: dayTour8h,
        date: june15,
        startTime: (hour: 20, minute: 0),
      )!;
      expect(w.end, DateTime(2026, 6, 16, 4));
      expect(w.nights, 1);
    });

    test('multi-night: each extra night adds a day, priced per night', () {
      final w = BookingLogic.computeWindow(
        stayType: overnight,
        date: june15,
        nights: 2,
        startTime: (hour: 15, minute: 0),
      )!;
      expect(w.start, DateTime(2026, 6, 15, 15));
      expect(w.end, DateTime(2026, 6, 17, 13)); // 22 h + 1 day
      expect(w.nights, 2);

      const rate = Rate(
        id: 'r',
        unitTypeId: 'ut_cottage',
        stayTypeId: 'st_overnight',
        price: 2500,
      );
      final q = BookingLogic.quote(rate: rate, stayType: overnight, window: w);
      expect(q.quantity, 2);
      expect(q.total, 5000);
    });

    test('an invalid start time gives no window', () {
      expect(
        BookingLogic.computeWindow(
          stayType: dayTour8h,
          date: june15,
          startTime: (hour: 24, minute: 0),
        ),
        isNull,
      );
    });
  });

  group('conflicts with calculated end times', () {
    final evening = saved(
      id: 'evening',
      start: DateTime(2026, 6, 15, 16),
      end: DateTime(2026, 6, 15, 20),
    );

    test('8-hour Day Tour ends as the next booking starts: no conflict', () {
      final w = BookingLogic.computeWindow(stayType: dayTour8h, date: june15)!;
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: w,
          existing: [evening],
        ),
        isEmpty,
      );
    });

    test('10-hour Day Tour now overlaps the same booking', () {
      final w = BookingLogic.computeWindow(stayType: dayTour10h, date: june15)!;
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: w,
          existing: [evening],
        ).map((r) => r.id),
        ['evening'],
      );
    });

    test('cancelled bookings and other units never block', () {
      final w = BookingLogic.computeWindow(stayType: dayTour10h, date: june15)!;
      final cancelled = saved(
        id: 'c',
        start: DateTime(2026, 6, 15, 16),
        end: DateTime(2026, 6, 15, 20),
        status: 'Cancelled',
      );
      final otherUnit = saved(
        id: 'o',
        unitId: 'unit_b',
        start: DateTime(2026, 6, 15, 16),
        end: DateTime(2026, 6, 15, 20),
      );
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: w,
          existing: [cancelled, otherUnit],
        ),
        isEmpty,
      );
    });
  });

  group('changing a duration does not alter existing reservations', () {
    // Booked while Day Tour was 8 hours.
    final existing = saved(
      start: DateTime(2026, 6, 15, 8),
      end: DateTime(2026, 6, 15, 16),
    );

    test('its saved end still decides availability', () {
      // Day Tour is now 10 hours, but the saved booking still ends at 4 PM,
      // so a 4:00 PM booking is still free.
      final later = BookingLogic.computeWindow(
        stayType: dayTour10h,
        date: june15,
        startTime: (hour: 16, minute: 0),
      )!;
      expect(
        BookingLogic.findConflicts(
          unitId: 'unit_a',
          window: later,
          existing: [existing],
        ),
        isEmpty,
      );
    });

    test('a guest-only edit keeps the saved start and end', () {
      final draft = ReservationDraft.fromReservation(
        existing,
      ).copyWith(phone: '0918 111 2222');
      final plan = ReservationWorkflow.planEdit(existing, draft);
      final body = ReservationWorkflow.buildUpdateBody(
        plan: plan,
        draft: draft,
      );
      expect(body, {'phone': '0918 111 2222'});
    });
  });

  group('rates stay tied to unit type + stay type', () {
    const rates = [
      Rate(
        id: 'a',
        unitTypeId: 'ut_cottage',
        stayTypeId: 'st_morning',
        price: 600,
      ),
      Rate(
        id: 'b',
        unitTypeId: 'ut_villa',
        stayTypeId: 'st_overnight',
        price: 5000,
      ),
    ];

    test('finds the rate for an owner-created stay type', () {
      expect(
        BookingLogic.findRate(
          rates: rates,
          unitTypeId: 'ut_cottage',
          stayTypeId: 'st_morning',
        )?.price,
        600,
      );
      expect(
        BookingLogic.findRate(
          rates: rates,
          unitTypeId: 'ut_villa',
          stayTypeId: 'st_morning',
        ),
        isNull,
      );
    });

    test('per-stay price is charged once whatever the duration', () {
      final w = BookingLogic.computeWindow(stayType: morning5h, date: june15)!;
      final q = BookingLogic.quote(
        rate: rates.first,
        stayType: morning5h,
        window: w,
      );
      expect(q.total, 600);
    });
  });

  group('ConfigRules: duration settings', () {
    test('check-out is calculated from check-in + duration', () {
      expect(
        ConfigRules.checkOutFor(checkInTime: '08:00', durationMinutes: 480),
        (checkOutTime: '16:00', endsNextDay: false),
      );
      expect(
        ConfigRules.checkOutFor(checkInTime: '14:00', durationMinutes: 1320),
        (checkOutTime: '12:00', endsNextDay: true),
      );
      expect(
        ConfigRules.checkOutFor(checkInTime: '16:00', durationMinutes: 480),
        (checkOutTime: '00:00', endsNextDay: true),
      );
      expect(
        ConfigRules.checkOutFor(checkInTime: '09:15', durationMinutes: 150),
        (checkOutTime: '11:45', endsNextDay: false),
      );
    });

    test('saved times give back the same duration', () {
      for (final st in [dayTour8h, overnight, overnight14h, morning5h]) {
        final out = ConfigRules.checkOutFor(
          checkInTime: st.checkInTime,
          durationMinutes: st.durationMinutes!,
        )!;
        expect(out.checkOutTime, st.checkOutTime, reason: st.name);
        expect(out.endsNextDay, st.endsNextDay, reason: st.name);
        expect(
          ConfigRules.durationFromTimes(
            checkInTime: st.checkInTime,
            checkOutTime: st.checkOutTime,
            endsNextDay: st.endsNextDay,
          ),
          st.durationMinutes,
        );
      }
    });

    test('duration validation', () {
      String? check(String inTime, int? minutes) =>
          ConfigRules.validateStayDuration(
            checkInTime: inTime,
            durationMinutes: minutes,
          );
      expect(check('08:00', 480), isNull);
      expect(check('', 480), isNotNull); // no check-in time
      expect(check('08:00', null), isNotNull);
      expect(check('08:00', 0), isNotNull);
      // From 2:00 PM a stay can last until 11:59 PM the next day.
      expect(check('14:00', 2039), isNull);
      expect(check('14:00', 2040), isNotNull);
      expect(
        ConfigRules.checkOutFor(checkInTime: '14:00', durationMinutes: 2040),
        isNull,
      );
    });
  });

  group('owner-created units', () {
    test('a new unit type and unit are sent to PocketBase as typed', () {
      const type = UnitType(id: '', name: 'Cottage', defaultCapacity: 10);
      const unit = Unit(
        id: '',
        name: 'Cottage 5',
        unitTypeId: 'ut_cottage',
        capacity: 10,
      );
      expect(type.toBody()['name'], 'Cottage');
      expect(unit.toBody(), containsPair('name', 'Cottage 5'));
      expect(unit.toBody(), containsPair('unitType', 'ut_cottage'));
      expect(unit.toBody(), containsPair('capacity', 10));
      expect(unit.toBody(), containsPair('isActive', true));
    });
  });

  test('DateFormatUtil.duration', () {
    expect(DateFormatUtil.duration(480), '8 hours');
    expect(DateFormatUtil.duration(60), '1 hour');
    expect(DateFormatUtil.duration(510), '8 hours 30 min');
    expect(DateFormatUtil.duration(45), '45 min');
    expect(DateFormatUtil.duration(1320), '22 hours');
  });
}
