// Widget tests for the Stage 6 booking-management actions.
//
// A small fake gateway stands in for PocketBase, so these tests run
// without a server and record which calls the screens make.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/rate.dart';
import 'package:final_project/models/reservation.dart';
import 'package:final_project/models/stay_type.dart';
import 'package:final_project/models/unit.dart';
import 'package:final_project/screens/add_reservation_screen.dart';
import 'package:final_project/screens/reservation_details_screen.dart';
import 'package:final_project/services/reservation_gateway.dart';
import 'package:final_project/theme/app_theme.dart';

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
const cottageOvernightRate = Rate(
  id: 'rate_1',
  unitTypeId: 'ut_cottage',
  stayTypeId: 'st_overnight',
  price: 2500,
);

/// Overnight Nov 10 2:00 PM → Nov 12 12:00 PM on Cottage A.
Reservation booking({String status = 'Reserved', String id = 'r1'}) {
  return Reservation(
    id: id,
    guestName: 'Maria Santos',
    phone: '0917 000 0000',
    email: 'maria@example.com',
    guestCount: 2,
    unitId: 'unit_a',
    stayTypeId: 'st_overnight',
    startAt: DateTime(2026, 11, 10, 14),
    endAt: DateTime(2026, 11, 12, 12),
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

/// Same reservation with another status.
Reservation withStatus(Reservation r, String status) {
  return Reservation(
    id: r.id,
    guestName: r.guestName,
    phone: r.phone,
    email: r.email,
    guestCount: r.guestCount,
    unitId: r.unitId,
    stayTypeId: r.stayTypeId,
    startAt: r.startAt,
    endAt: r.endAt,
    status: status,
    notes: r.notes,
    unitName: r.unitName,
    unitTypeName: r.unitTypeName,
    stayTypeName: r.stayTypeName,
    rate: r.rate,
    rateBasis: r.rateBasis,
    quantity: r.quantity,
    totalAmount: r.totalAmount,
  );
}

/// Records every call instead of talking to PocketBase.
class FakeGateway extends ReservationGateway {
  FakeGateway(this.current, {this.overlapping = const []});

  Reservation current;
  List<Reservation> overlapping;

  /// Calls in order, e.g. ['overlap', 'status:Reserved'].
  final calls = <String>[];
  final updates = <Map<String, dynamic>>[];

  List<String> get statusUpdates => [
    for (final c in calls)
      if (c.startsWith('status:')) c.substring('status:'.length),
  ];

  @override
  Future<Reservation> getReservation(String id) async => current;

  @override
  Future<Reservation> updateStatus(String id, String status) async {
    calls.add('status:$status');
    current = withStatus(current, status);
    return current;
  }

  @override
  Future<Reservation> updateReservation(
    String id,
    Map<String, dynamic> body,
  ) async {
    calls.add('update');
    updates.add(body);
    return current;
  }

  @override
  Future<List<Reservation>> findOverlapping({
    required String unitId,
    required DateTime start,
    required DateTime end,
    String? excludeReservationId,
  }) async {
    calls.add('overlap');
    return overlapping;
  }

  @override
  Future<List<StayType>> getStayTypes({bool activeOnly = false}) async => [
    overnight,
    dayTour,
  ];

  @override
  Future<List<Unit>> getUnits({bool activeOnly = false}) async => [
    cottageA,
    cottageB,
  ];

  @override
  Future<List<Rate>> getRates() async => [cottageOvernightRate];
}

// Nov 11 is after the Nov 10 check-in date; Nov 9 is before it.
final afterCheckIn = DateTime(2026, 11, 11, 9);
final beforeCheckIn = DateTime(2026, 11, 9, 9);

Future<void> pumpDetails(
  WidgetTester tester,
  FakeGateway fake, {
  DateTime? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: ReservationDetailsScreen(
        reservation: fake.current,
        gateway: fake,
        clock: () => now ?? afterCheckIn,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the edit form from a host page (so Save can close it) and
/// returns a function that reads the page's result.
Future<bool? Function()> pumpEdit(WidgetTester tester, FakeGateway fake) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AddReservationScreen(
                      reservation: fake.current,
                      gateway: fake,
                    ),
                  ),
                );
              },
              child: const Text('open edit'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open edit'));
  await tester.pumpAndSettle();
  return () => result;
}

Finder action(String name) => find.byKey(ValueKey('action-$name'));

bool isEnabled(WidgetTester tester, String name) =>
    tester.widget<ButtonStyleButton>(action(name)).enabled;

Finder inDialog(String text) =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

void main() {
  group('Details action states', () {
    testWidgets('Reserved: Edit, Cancel and Check In (on/after the date)', (
      tester,
    ) async {
      await pumpDetails(tester, FakeGateway(booking()));

      expect(isEnabled(tester, 'edit'), isTrue);
      expect(isEnabled(tester, 'cancel'), isTrue);
      expect(isEnabled(tester, 'checkin'), isTrue);
      expect(action('complete'), findsNothing);
      expect(action('restore'), findsNothing);
    });

    testWidgets('Reserved: Check In is disabled before the check-in date', (
      tester,
    ) async {
      await pumpDetails(tester, FakeGateway(booking()), now: beforeCheckIn);

      expect(isEnabled(tester, 'checkin'), isFalse);
      expect(isEnabled(tester, 'edit'), isTrue);
      expect(find.textContaining('Check-in opens on'), findsOneWidget);
    });

    testWidgets('Checked In: Mark Completed and Edit, no Cancel', (
      tester,
    ) async {
      await pumpDetails(tester, FakeGateway(booking(status: 'Checked In')));

      expect(isEnabled(tester, 'complete'), isTrue);
      expect(isEnabled(tester, 'edit'), isTrue);
      expect(action('cancel'), findsNothing);
      expect(action('checkin'), findsNothing);
    });

    testWidgets('Completed: no Edit, no Cancel, no status action', (
      tester,
    ) async {
      await pumpDetails(tester, FakeGateway(booking(status: 'Completed')));

      expect(isEnabled(tester, 'edit'), isFalse);
      expect(action('cancel'), findsNothing);
      expect(action('checkin'), findsNothing);
      expect(action('complete'), findsNothing);
      expect(action('restore'), findsNothing);
      expect(
        find.text('Completed reservations can no longer be edited.'),
        findsOneWidget,
      );
    });

    testWidgets('Cancelled: Restore only', (tester) async {
      await pumpDetails(tester, FakeGateway(booking(status: 'Cancelled')));

      expect(isEnabled(tester, 'restore'), isTrue);
      expect(isEnabled(tester, 'edit'), isFalse);
      expect(action('cancel'), findsNothing);
      expect(action('checkin'), findsNothing);
    });
  });

  group('Cancel dialog', () {
    testWidgets('shows a confirmation with the booking summary', (
      tester,
    ) async {
      await pumpDetails(tester, FakeGateway(booking()));

      await tester.tap(action('cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel this reservation?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Maria Santos'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('available again'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dismissing does not change the reservation', (tester) async {
      final fake = FakeGateway(booking());
      await pumpDetails(tester, fake);

      await tester.tap(action('cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep Reservation'));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(action('cancel'), findsOneWidget);
    });

    testWidgets('confirming cancels and shows Restore', (tester) async {
      final fake = FakeGateway(booking());
      await pumpDetails(tester, fake);

      await tester.tap(action('cancel'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Cancel Reservation'));
      await tester.pumpAndSettle();

      expect(fake.statusUpdates, ['Cancelled']);
      expect(action('restore'), findsOneWidget);
      expect(action('cancel'), findsNothing);
      expect(find.text('Cancelled'), findsWidgets); // status badge
    });
  });

  group('Status actions', () {
    testWidgets('Check In asks first, then updates the status', (tester) async {
      final fake = FakeGateway(booking());
      await pumpDetails(tester, fake);

      await tester.tap(action('checkin'));
      await tester.pumpAndSettle();
      expect(find.text('Check in this guest?'), findsOneWidget);
      await tester.tap(inDialog('Check In'));
      await tester.pumpAndSettle();

      expect(fake.statusUpdates, ['Checked In']);
      expect(action('complete'), findsOneWidget);
    });

    testWidgets('Mark Completed asks first, then updates the status', (
      tester,
    ) async {
      final fake = FakeGateway(booking(status: 'Checked In'));
      await pumpDetails(tester, fake);

      await tester.tap(action('complete'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Mark Completed'));
      await tester.pumpAndSettle();

      expect(fake.statusUpdates, ['Completed']);
      expect(isEnabled(tester, 'edit'), isFalse);
    });

    testWidgets('Restore checks availability before updating the status', (
      tester,
    ) async {
      final fake = FakeGateway(booking(status: 'Cancelled'));
      await pumpDetails(tester, fake);

      await tester.tap(action('restore'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Restore'));
      await tester.pumpAndSettle();

      expect(fake.calls, ['overlap', 'status:Reserved']);
      expect(action('cancel'), findsOneWidget);
    });

    testWidgets('Restore is refused when the slot is taken', (tester) async {
      final other = Reservation(
        id: 'r2',
        guestName: 'Juan Cruz',
        phone: '',
        email: '',
        unitId: 'unit_a',
        stayTypeId: 'st_day',
        startAt: DateTime(2026, 11, 11, 8),
        endAt: DateTime(2026, 11, 11, 17),
        status: 'Reserved',
      );
      final fake = FakeGateway(
        booking(status: 'Cancelled'),
        overlapping: [other],
      );
      await pumpDetails(tester, fake);

      await tester.tap(action('restore'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Restore'));
      await tester.pumpAndSettle();

      expect(fake.calls, ['overlap']);
      expect(find.text("Can't restore this reservation"), findsOneWidget);
      expect(find.textContaining('Juan Cruz'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(action('restore'), findsOneWidget);
    });
  });

  group('Edit mode', () {
    testWidgets('fields are prefilled and Save Changes is shown', (
      tester,
    ) async {
      await pumpEdit(tester, FakeGateway(booking()));

      expect(find.text('Edit Reservation'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Save Reservation'), findsNothing);
      expect(
        find.widgetWithText(TextFormField, 'Maria Santos'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, '0917 000 0000'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'maria@example.com'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, '2'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Late arrival'),
        findsOneWidget,
      );
      expect(find.textContaining('Cottage A'), findsWidgets);
      expect(find.text('November 10, 2026'), findsOneWidget);
      expect(find.text('November 12, 2026'), findsOneWidget);
    });

    testWidgets('Checked In locks unit, stay type and dates', (tester) async {
      await pumpEdit(tester, FakeGateway(booking(status: 'Checked In')));

      expect(find.byKey(const ValueKey('locked-stay-type')), findsOneWidget);
      expect(find.byKey(const ValueKey('locked-unit')), findsOneWidget);
      expect(find.byKey(const ValueKey('locked-check-in')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-locked-note')),
        findsOneWidget,
      );
      // Guest fields stay editable.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('locked-unit')),
          matching: find.byType(TextFormField),
        ),
        findsNothing,
      );
    });

    testWidgets('Reserved allows schedule editing', (tester) async {
      await pumpEdit(tester, FakeGateway(booking()));

      expect(find.byKey(const ValueKey('locked-stay-type')), findsNothing);
      expect(find.byKey(const ValueKey('locked-unit')), findsNothing);
      expect(find.byKey(const ValueKey('locked-check-in')), findsNothing);
    });

    testWidgets('guest-only edit saves only that field, no re-check', (
      tester,
    ) async {
      final fake = FakeGateway(booking());
      final result = await pumpEdit(tester, fake);

      await tester.enterText(
        find.widgetWithText(TextFormField, '0917 000 0000'),
        '0918 999 9999',
      );
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(fake.calls, ['update']);
      expect(fake.updates.single, {'phone': '0918 999 9999'});
      expect(result(), isTrue);
    });

    testWidgets('unit change re-checks availability and re-prices', (
      tester,
    ) async {
      final fake = FakeGateway(booking());
      await pumpEdit(tester, fake);

      await tester.ensureVisible(find.byType(DropdownButtonFormField<Unit>));
      await tester.tap(find.byType(DropdownButtonFormField<Unit>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Cottage B').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('price-change-note')), findsOneWidget);

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(fake.calls, ['overlap', 'update']);
      final body = fake.updates.single;
      expect(body['unit'], 'unit_b');
      expect(body['unitName'], 'Cottage B');
      expect(body['totalAmount'], 5000); // ₱2,500 × 2 nights
      expect(body.containsKey('status'), isFalse);
    });
  });
}
