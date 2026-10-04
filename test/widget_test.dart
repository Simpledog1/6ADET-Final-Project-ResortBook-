// A widget test: it builds your app in memory and checks what is on screen.
// Run them all with: flutter test
//
// The dashboard gets a fake data source, so this test never contacts
// PocketBase. (In widget tests every real HTTP request is answered with an
// empty "400" response by the test framework, which is what used to print
// "Error fetching reservations: ClientException ... statusCode: 400".)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/screens/dashboard_screen.dart';
import 'package:final_project/theme/app_theme.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('dashboard shows the header and hub buttons', (tester) async {
    // Build the dashboard directly, without the DevicePreview wrapper,
    // because a test does not need the phone frame.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DashboardScreen(gateway: FakeGateway()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ResortBook'), findsOneWidget);
    expect(find.text('Upcoming Reservations'), findsOneWidget);
    expect(find.text('Add Reservation'), findsOneWidget);
    expect(find.text('View Reservations'), findsOneWidget);
    expect(find.text('View Calendar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNWidgets(3));
    expect(find.text('No upcoming reservations.'), findsOneWidget);
  });

  testWidgets('dashboard lists upcoming reservations from its data source', (
    tester,
  ) async {
    final now = DateTime.now();
    final fake = FakeGateway(
      reservations: [
        makeReservation(
          guestName: 'Upcoming Guest',
          start: now.add(const Duration(days: 2)),
          end: now.add(const Duration(days: 3)),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DashboardScreen(gateway: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(fake.reservationLoads, 1);
    expect(find.text('Upcoming Guest'), findsOneWidget);
  });
}
