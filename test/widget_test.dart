// A widget test: it builds your app in memory and checks what is on screen.
// Run them all with: flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/screens/dashboard_screen.dart';
import 'package:final_project/theme/app_theme.dart';

void main() {
  testWidgets('dashboard shows the header and hub buttons', (tester) async {
    // Build the dashboard directly, without the DevicePreview wrapper,
    // because a test does not need the phone frame.
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const DashboardScreen()),
    );

    expect(find.text('ResortBook'), findsOneWidget);
    expect(find.text('Upcoming Reservations'), findsOneWidget);
    expect(find.text('Add Reservation'), findsOneWidget);
    expect(find.text('View Reservations'), findsOneWidget);
    expect(find.text('View Calendar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNWidgets(3));
  });
}
