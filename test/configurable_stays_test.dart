// Widget tests for owner-configured units and stay durations:
// Add Reservation offers the units loaded from PocketBase and calculates the
// end time from the stay type's duration; the Stay Type form edits that
// duration. Uses the fake gateway (no PocketBase server needed).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/rate.dart';
import 'package:final_project/models/reservation.dart';
import 'package:final_project/models/stay_type.dart';
import 'package:final_project/models/unit.dart';
import 'package:final_project/screens/add_reservation_screen.dart';
import 'package:final_project/screens/manage/stay_type_form.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:final_project/widgets/responsive.dart';

import 'support/fake_gateway.dart';

// Owner configuration for these tests.
const dayTour8h = StayType(
  id: 'st_day',
  name: 'Day Tour',
  checkInTime: '08:00',
  checkOutTime: '16:00',
);
const dayTour10h = StayType(
  id: 'st_day',
  name: 'Day Tour',
  checkInTime: '08:00',
  checkOutTime: '18:00',
);
const cottage5 = Unit(
  id: 'unit_5',
  name: 'Cottage 5',
  unitTypeId: 'ut_cottage',
  capacity: 10,
);
const closedHut = Unit(
  id: 'unit_closed',
  name: 'Closed Hut',
  unitTypeId: 'ut_cottage',
  capacity: 2,
  isActive: false,
);
const dayRate = Rate(
  id: 'rate_day',
  unitTypeId: 'ut_cottage',
  stayTypeId: 'st_day',
  price: 800,
);

FakeGateway gatewayFor(StayType dayTour) => FakeGateway(
  stayTypes: [dayTour],
  units: [cottageA, cottage5, closedHut],
  rates: [dayRate],
);

void setWindowSize(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpAdd(
  WidgetTester tester,
  FakeGateway fake, {
  bool desktop = false,
}) async {
  final screen = AddReservationScreen(gateway: fake);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: desktop ? DesktopShellScope(child: screen) : screen,
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the unit dropdown (leaves it open).
Future<void> openUnits(WidgetTester tester) async {
  final dropdown = find.byType(DropdownButtonFormField<Unit>);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
}

/// Fills a Day Tour booking on Cottage 5 for today (the date picker's
/// initial date) with 3 guests.
Future<void> fillBooking(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Enter guest name'),
    'Ana Reyes',
  );
  await openUnits(tester);
  await tester.tap(find.text('Cottage 5 · up to 10').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Up to 10'), '3');

  final date = find.text('Select check-in date');
  await tester.ensureVisible(date);
  await tester.tap(date);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  final save = find.text('Save Reservation');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

void main() {
  group('Add Reservation with owner-configured units', () {
    testWidgets('a newly created active unit is offered; inactive ones are '
        'not', (tester) async {
      await pumpAdd(tester, gatewayFor(dayTour8h));
      await openUnits(tester);

      expect(find.text('Cottage 5 · up to 10'), findsWidgets);
      expect(find.text('Cottage A · up to 4'), findsWidgets);
      expect(find.textContaining('Closed Hut'), findsNothing);
    });
  });

  group('Add new unit from the Unit field', () {
    Future<void> openAddUnit(WidgetTester tester) async {
      await openUnits(tester);
      await tester.tap(find.text('Add new unit…').last);
      await tester.pumpAndSettle();
    }

    Future<void> typeUnit(
      WidgetTester tester, {
      required String name,
      required String type,
      required String capacity,
    }) async {
      await tester.enterText(
        find.byKey(const ValueKey('quick-unit-name')),
        name,
      );
      await tester.enterText(
        find.byKey(const ValueKey('quick-unit-type')),
        type,
      );
      await tester.enterText(
        find.byKey(const ValueKey('quick-unit-capacity')),
        capacity,
      );
      await tester.pump();
    }

    Future<void> tapAddUnit(WidgetTester tester) async {
      final button = find.text('Add Unit');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('a typed new unit type is created, priced and selected', (
      tester,
    ) async {
      final fake = gatewayFor(dayTour8h);
      await pumpAdd(tester, fake);
      await openAddUnit(tester);

      await typeUnit(
        tester,
        name: 'Function Hall',
        type: 'Events Hall',
        capacity: '50',
      );
      expect(
        find.text('New unit type "Events Hall" will be created.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('quick-unit-price')),
        '5000',
      );
      await tapAddUnit(tester);

      expect(fake.calls, ['createUnitType', 'createUnit', 'saveRate']);
      expect(fake.unitTypes.last.name, 'Events Hall');
      expect(
        find.text('Function Hall · Events Hall · up to 50'),
        findsOneWidget,
      );

      // The new unit can be booked straight away with its new price.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter guest name'),
        'Liza Bautista',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Up to 50'),
        '30',
      );
      final date = find.text('Select check-in date');
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tapSave(tester);

      final r = fake.created.single;
      expect(r.unitName, 'Function Hall');
      expect(r.unitTypeName, 'Events Hall');
      expect(r.totalAmount, 5000);
    });

    testWidgets('typing an existing type name reuses that type', (
      tester,
    ) async {
      final fake = gatewayFor(dayTour8h);
      await pumpAdd(tester, fake);
      await openAddUnit(tester);

      await typeUnit(tester, name: 'Cottage 9', type: 'cottage', capacity: '4');
      expect(
        find.text('Uses the existing unit type "Cottage".'),
        findsOneWidget,
      );
      // Cottage already has a Day Tour rate, so no price is asked for.
      expect(find.byKey(const ValueKey('quick-unit-price')), findsNothing);
      await tapAddUnit(tester);

      expect(fake.calls, ['createUnit']);
      expect(fake.units.last.unitTypeId, 'ut_cottage');
      expect(find.text('Cottage 9 · Cottage · up to 4'), findsOneWidget);
    });

    testWidgets('a duplicate unit name is refused', (tester) async {
      final fake = gatewayFor(dayTour8h);
      await pumpAdd(tester, fake);
      await openAddUnit(tester);

      await typeUnit(tester, name: 'cottage a', type: 'Cottage', capacity: '4');
      await tapAddUnit(tester);

      expect(find.textContaining('already exists'), findsOneWidget);
      expect(fake.calls, isEmpty);
    });
  });

  group('Add Reservation with owner-configured durations', () {
    testWidgets('stay type shows its start time and duration', (tester) async {
      await pumpAdd(tester, gatewayFor(dayTour8h));
      expect(find.text('8:00 AM · 8 hours'), findsWidgets);
    });

    testWidgets('Day Tour = 8 hours: saved from 8:00 AM to 4:00 PM', (
      tester,
    ) async {
      final fake = gatewayFor(dayTour8h);
      await pumpAdd(tester, fake);
      await fillBooking(tester);
      await tapSave(tester);

      expect(fake.calls, ['overlap', 'create']);
      final r = fake.created.single;
      expect(r.unitId, 'unit_5');
      expect(r.stayTypeId, 'st_day');
      expect(r.startAt, today().add(const Duration(hours: 8)));
      expect(r.endAt, today().add(const Duration(hours: 16)));
      expect(r.totalAmount, 800);
    });

    testWidgets('after changing Day Tour to 10 hours, new bookings end at '
        '6:00 PM', (tester) async {
      final fake = gatewayFor(dayTour10h);
      await pumpAdd(tester, fake);
      await fillBooking(tester);
      await tapSave(tester);

      expect(fake.created.single.endAt, today().add(const Duration(hours: 18)));
    });

    // Cottage 5 is booked from 5:00 PM today.
    Reservation evening() => makeReservation(
      id: 'evening',
      guestName: 'Juan Cruz',
      unitId: 'unit_5',
      unitName: 'Cottage 5',
      start: today().add(const Duration(hours: 17)),
      end: today().add(const Duration(hours: 21)),
    );

    testWidgets('8-hour stay ending before the next booking is saved', (
      tester,
    ) async {
      final fake = gatewayFor(dayTour8h)..overlapping = [evening()];
      await pumpAdd(tester, fake);
      await fillBooking(tester);
      await tapSave(tester);
      expect(fake.calls, ['overlap', 'create']);
    });

    testWidgets('10-hour stay overlapping the next booking is blocked', (
      tester,
    ) async {
      final fake = gatewayFor(dayTour10h)..overlapping = [evening()];
      await pumpAdd(tester, fake);
      await fillBooking(tester);
      await tapSave(tester);
      expect(fake.calls, ['overlap']);
      expect(fake.created, isEmpty);
      expect(find.text('Date Conflict Detected'), findsOneWidget);
      expect(find.textContaining('Juan Cruz'), findsOneWidget);
    });

    testWidgets('a cancelled booking does not block', (tester) async {
      final cancelled = makeReservation(
        id: 'c',
        unitId: 'unit_5',
        start: today().add(const Duration(hours: 9)),
        end: today().add(const Duration(hours: 12)),
        status: 'Cancelled',
      );
      final fake = gatewayFor(dayTour8h)..overlapping = [cancelled];
      await pumpAdd(tester, fake);
      await fillBooking(tester);
      await tapSave(tester);
      expect(fake.calls, ['overlap', 'create']);
    });
  });

  group('layouts', () {
    testWidgets('phone: check-in time field fits', (tester) async {
      setWindowSize(tester, 390, 844);
      await pumpAdd(tester, gatewayFor(dayTour8h));
      expect(find.text('Check-in Time'), findsOneWidget);
      expect(find.byKey(const ValueKey('start-time')), findsOneWidget);
    });

    testWidgets('desktop: date, time and check-out side by side', (
      tester,
    ) async {
      setWindowSize(tester, 1280, 1000);
      await pumpAdd(tester, gatewayFor(dayTour8h), desktop: true);
      expect(find.text('Check-in Date'), findsOneWidget);
      expect(find.text('Check-in Time'), findsOneWidget);
      expect(find.text('Check-out'), findsOneWidget);
      final date = tester.getTopLeft(find.text('Check-in Date'));
      final time = tester.getTopLeft(find.text('Check-in Time'));
      expect(time.dy, date.dy);
      expect(time.dx, greaterThan(date.dx));
    });
  });

  group('Stay Type form: duration', () {
    Future<void> pumpForm(WidgetTester tester, StayType existing) async {
      setWindowSize(tester, 600, 1400);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StayTypeForm(existing: existing, otherNames: const []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String hours(WidgetTester tester) => tester
        .widget<TextFormField>(find.byKey(const ValueKey('duration-hours')))
        .controller!
        .text;

    testWidgets('shows the saved duration and recalculates check-out', (
      tester,
    ) async {
      await pumpForm(tester, dayTour); // 8:00 AM → 5:00 PM
      expect(hours(tester), '9');
      expect(
        find.textContaining('Check-out: 5:00 PM the same day'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const ValueKey('duration-hours')), '8');
      await tester.pump();
      expect(
        find.textContaining('Check-out: 4:00 PM the same day'),
        findsOneWidget,
      );
      expect(
        find.textContaining('8:00 AM → 4:00 PM · 8 hours'),
        findsOneWidget,
      );
    });

    testWidgets('an overnight duration ends the next day', (tester) async {
      await pumpForm(tester, overnight); // 2:00 PM, 22 hours
      expect(hours(tester), '22');
      expect(
        find.textContaining('Check-out: 12:00 PM the next day'),
        findsOneWidget,
      );
    });

    testWidgets('a duration past the next day is refused before saving', (
      tester,
    ) async {
      await pumpForm(tester, dayTour);
      await tester.enterText(
        find.byKey(const ValueKey('duration-hours')),
        '48',
      );
      await tester.pump();
      final save = find.text('Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(find.textContaining('must end by the next day'), findsOneWidget);
    });
  });
}
