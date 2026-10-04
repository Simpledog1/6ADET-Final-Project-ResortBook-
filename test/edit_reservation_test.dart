// Edit Reservation widget tests for the less common paths: conflicts,
// missing rates, capacity, older reservations, inactive configuration and
// load errors. (The basic edit flow is in reservation_details_actions_test.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/reservation.dart';
import 'package:final_project/models/stay_type.dart';
import 'package:final_project/models/unit.dart';
import 'package:final_project/screens/add_reservation_screen.dart';
import 'package:final_project/screens/reservation_details_screen.dart';
import 'package:final_project/theme/app_theme.dart';

import 'support/fake_gateway.dart';

/// Overnight Nov 10 2:00 PM → Nov 12 12:00 PM on Cottage A (2 nights).
Reservation booking({
  String status = 'Reserved',
  String unitId = 'unit_a',
  String unitName = 'Cottage A',
  String stayTypeId = 'st_overnight',
  String stayTypeName = 'Overnight',
  int guestCount = 2,
}) => makeReservation(
  guestCount: guestCount,
  unitId: unitId,
  unitName: unitName,
  stayTypeId: stayTypeId,
  stayTypeName: stayTypeName,
  start: DateTime(2026, 11, 10, 14),
  end: DateTime(2026, 11, 12, 12),
  status: status,
  quantity: 2,
  totalAmount: 5000,
);

/// Opens the edit form from a host page so Save can close it.
Future<void> pumpEdit(WidgetTester tester, FakeGateway fake) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AddReservationScreen(
                    reservation: fake.current,
                    gateway: fake,
                  ),
                ),
              ),
              child: const Text('open edit'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open edit'));
  await tester.pumpAndSettle();
}

Future<void> chooseUnit(WidgetTester tester, String name) async {
  final dropdown = find.byType(DropdownButtonFormField<Unit>);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(name).last);
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Changes'));
  await tester.tap(find.text('Save Changes'));
  await tester.pumpAndSettle();
}

bool saveEnabled(WidgetTester tester) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Save Changes'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    )
    .enabled;

void main() {
  testWidgets('a conflicting unit change is blocked and nothing is saved', (
    tester,
  ) async {
    final other = makeReservation(
      id: 'r2',
      guestName: 'Juan Cruz',
      unitId: 'unit_b',
      start: DateTime(2026, 11, 11, 14),
      end: DateTime(2026, 11, 12, 12),
    );
    final fake = FakeGateway(current: booking(), overlapping: [other]);
    await pumpEdit(tester, fake);

    await chooseUnit(tester, 'Cottage B');
    await tapSave(tester);

    expect(fake.calls, ['overlap']);
    expect(fake.updates, isEmpty);
    expect(find.text('Date Conflict Detected'), findsOneWidget);
    expect(find.textContaining('Juan Cruz'), findsOneWidget);
  });

  testWidgets('a missing rate blocks saving a schedule change', (tester) async {
    final fake = FakeGateway(current: booking(), rates: []);
    await pumpEdit(tester, fake);

    // Guest-only changes don't need a rate…
    expect(find.text('No Rate Set'), findsNothing);
    expect(saveEnabled(tester), isTrue);

    // …but moving the booking does.
    await chooseUnit(tester, 'Cottage B');
    expect(find.text('No Rate Set'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    expect(fake.calls, isEmpty);
  });

  testWidgets('guest count above capacity shows an error', (tester) async {
    final fake = FakeGateway(current: booking());
    await pumpEdit(tester, fake);

    await tester.enterText(find.widgetWithText(TextFormField, '2'), '9');
    await tapSave(tester);

    expect(find.text('Cottage A fits up to 4 guests.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('older reservation without a stay type: guest-only edit saves', (
    tester,
  ) async {
    final legacy = booking(stayTypeId: '', stayTypeName: '', guestCount: 0);
    final fake = FakeGateway(current: legacy);
    await pumpEdit(tester, fake);

    expect(
      find.textContaining('Older reservation: no stay type was saved'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, '0917 000 0000'),
      '0918 111 2222',
    );
    await tapSave(tester);

    expect(fake.calls, ['update']);
    expect(fake.updates.single, {'phone': '0918 111 2222'});
  });

  testWidgets('older reservation: changing the unit asks for a stay type', (
    tester,
  ) async {
    final legacy = booking(stayTypeId: '', stayTypeName: '');
    final fake = FakeGateway(current: legacy);
    await pumpEdit(tester, fake);

    await chooseUnit(tester, 'Cottage B');
    await tapSave(tester);

    expect(find.textContaining('Choose a stay type'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('inactive current unit and stay type stay selectable', (
    tester,
  ) async {
    const oldVilla = Unit(
      id: 'unit_old',
      name: 'Old Villa',
      unitTypeId: 'ut_cottage',
      capacity: 8,
      isActive: false,
    );
    const closedHut = Unit(
      id: 'unit_closed',
      name: 'Closed Hut',
      unitTypeId: 'ut_cottage',
      capacity: 2,
      isActive: false,
    );
    const oldPackage = StayType(
      id: 'st_old',
      name: 'Old Package',
      checkInTime: '09:00',
      checkOutTime: '15:00',
      isActive: false,
    );
    const retiredPackage = StayType(
      id: 'st_retired',
      name: 'Retired Package',
      checkInTime: '09:00',
      checkOutTime: '15:00',
      isActive: false,
    );
    final fake = FakeGateway(
      current: booking(
        unitId: 'unit_old',
        unitName: 'Old Villa',
        stayTypeId: 'st_old',
        stayTypeName: 'Old Package',
      ),
      units: [cottageA, oldVilla, closedHut],
      stayTypes: [overnight, oldPackage, retiredPackage],
    );
    await pumpEdit(tester, fake);

    // The reservation's own inactive items are offered and marked.
    expect(find.text('Old Package (inactive)'), findsOneWidget);
    expect(find.textContaining('Retired Package'), findsNothing);

    final dropdown = find.byType(DropdownButtonFormField<Unit>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(find.textContaining('Old Villa · up to 8 (inactive)'), findsWidgets);
    expect(find.textContaining('Closed Hut'), findsNothing);
  });

  testWidgets('a load error shows Retry, which reloads the form', (
    tester,
  ) async {
    final fake = FakeGateway(current: booking())..failLoads = true;
    await pumpEdit(tester, fake);

    expect(find.text('Connection problem'), findsOneWidget);
    expect(find.textContaining('Cannot reach PocketBase'), findsOneWidget);

    fake.failLoads = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Connection problem'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Maria Santos'), findsOneWidget);
  });

  group('timelineProgress', () {
    final now = DateTime(2026, 11, 11, 9); // Nov 11, 9:00 AM

    test('Checked In marks check-in done even before the scheduled time', () {
      final r = makeReservation(
        status: 'Checked In',
        start: DateTime(2026, 11, 11, 14),
        end: DateTime(2026, 11, 12, 12),
      );
      final p = timelineProgress(r, now);
      expect(p.checkIn, isTrue);
      expect(p.checkOut, isFalse);
    });

    test('Completed marks both done', () {
      final p = timelineProgress(booking(status: 'Completed'), now);
      expect(p.checkIn, isTrue);
      expect(p.checkOut, isTrue);
    });

    test('Cancelled marks neither done', () {
      final p = timelineProgress(booking(status: 'Cancelled'), now);
      expect(p.checkIn, isFalse);
      expect(p.checkOut, isFalse);
    });

    test('Reserved falls back to the scheduled times', () {
      final p = timelineProgress(booking(), now); // Nov 10 → Nov 12
      expect(p.checkIn, isTrue);
      expect(p.checkOut, isFalse);
    });
  });
}
