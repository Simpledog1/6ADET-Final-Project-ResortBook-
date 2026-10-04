// Widget tests for the Dashboard, Reservation List and Calendar using a
// fake gateway (no PocketBase server needed).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/logic/reservation_stats.dart';
import 'package:final_project/models/reservation.dart';
import 'package:final_project/screens/calendar_screen.dart';
import 'package:final_project/screens/dashboard_screen.dart';
import 'package:final_project/screens/reservation_list_screen.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:final_project/widgets/admin_table.dart';
import 'package:final_project/widgets/desktop_page.dart';
import 'package:final_project/widgets/filter_controls.dart';
import 'package:final_project/widgets/reservation_cards.dart';
import 'package:final_project/widgets/responsive.dart';
import 'package:final_project/widgets/stat_card.dart';

import 'support/fake_gateway.dart';

/// "Now" for every test: Wednesday, Nov 11 2026, 10:00 AM.
final now = DateTime(2026, 11, 11, 10);
DateTime clock() => now;

/// Sets the test window size (logical pixels) for this test.
void setWindowSize(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Desktop: the screen inside the sidebar shell scope, like the real app.
Future<void> pumpDesktop(
  WidgetTester tester,
  Widget screen, {
  double width = 1440,
}) async {
  setWindowSize(tester, width, 1000);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: DesktopShellScope(child: screen),
    ),
  );
  await tester.pumpAndSettle();
}

/// Phone / tablet: the screen on its own (default 800 × 600 test window).
Future<void> pumpMobile(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.lightTheme, home: screen),
  );
  await tester.pumpAndSettle();
}

// ── Reservation List data ───────────────────────────────────────────────

/// 25 reservations "Guest 01" … "Guest 25" (Guest 25 has the latest
/// check-in): 3 Checked In, 1 Completed, 2 Cancelled, 19 Reserved.
List<Reservation> listData() {
  String statusFor(int i) {
    if (i <= 3) return 'Checked In';
    if (i == 4) return 'Completed';
    if (i <= 6) return 'Cancelled';
    return 'Reserved';
  }

  return [
    for (var i = 1; i <= 25; i++)
      makeReservation(
        id: 'r$i',
        guestName: 'Guest ${i.toString().padLeft(2, '0')}',
        start: DateTime(2026, 11, i, 14),
        end: DateTime(2026, 11, i + 1, 12),
        status: statusFor(i),
      ),
  ];
}

Finder chipText(String text) => find.descendant(
  of: find.byType(FilterChipBar<ReservationStatusFilter>),
  matching: find.text(text),
);

Finder pageButton(String text) => find.descendant(
  of: find.byType(AdminPagination),
  matching: find.text(text),
);

// ── Calendar helpers ────────────────────────────────────────────────────

/// The desktop month grid (a private widget, found by its type name).
final monthGrid = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_DesktopMonthGrid',
);

Finder inGrid(String text) =>
    find.descendant(of: monthGrid, matching: find.text(text));

List<Reservation> calendarData() => [
  // Overnight, 3 nights: Nov 10 → Nov 13.
  makeReservation(
    id: 'multi',
    guestName: 'Multi Guest',
    start: DateTime(2026, 11, 10, 14),
    end: DateTime(2026, 11, 13, 12),
  ),
  // Night Tour across midnight: Nov 14 → Nov 15.
  makeReservation(
    id: 'night',
    guestName: 'Night Guest',
    unitId: 'unit_b',
    stayTypeId: 'st_night',
    stayTypeName: 'Night Tour',
    start: DateTime(2026, 11, 14, 19),
    end: DateTime(2026, 11, 15, 6),
  ),
  // Five bookings on Nov 20 (one cancelled) → 3 bars + "+2 more".
  for (var i = 1; i <= 4; i++)
    makeReservation(
      id: 'busy$i',
      guestName: 'Busy $i',
      unitId: 'unit_$i',
      stayTypeId: 'st_day',
      start: DateTime(2026, 11, 20, 8 + i),
      end: DateTime(2026, 11, 20, 17),
    ),
  makeReservation(
    id: 'busyCancelled',
    guestName: 'Busy Cancelled',
    status: 'Cancelled',
    stayTypeId: 'st_day',
    start: DateTime(2026, 11, 20, 7),
    end: DateTime(2026, 11, 20, 9),
  ),
  // Nov 25: a cancelled booking that starts earlier than an active one.
  makeReservation(
    id: 'earlyCancel',
    guestName: 'Early Cancel',
    status: 'Cancelled',
    stayTypeId: 'st_day',
    start: DateTime(2026, 11, 25, 7),
    end: DateTime(2026, 11, 25, 9),
  ),
  makeReservation(
    id: 'lateActive',
    guestName: 'Late Active',
    unitId: 'unit_b',
    stayTypeId: 'st_night',
    start: DateTime(2026, 11, 25, 19),
    end: DateTime(2026, 11, 25, 23),
  ),
];

// ── Dashboard data ──────────────────────────────────────────────────────

List<Reservation> dashboardData() => [
  makeReservation(
    id: 'staying',
    guestName: 'Staying Guest',
    status: 'Checked In',
    start: DateTime(2026, 11, 10, 14),
    end: DateTime(2026, 11, 12, 12),
  ),
  // Checked out early: booked end time is still in the future.
  makeReservation(
    id: 'leftEarly',
    guestName: 'Early Leaver',
    unitId: 'unit_b',
    status: 'Completed',
    start: DateTime(2026, 11, 10, 14),
    end: DateTime(2026, 11, 12, 12),
  ),
  makeReservation(
    id: 'cancelled',
    guestName: 'Cancelled Guest',
    status: 'Cancelled',
    stayTypeId: 'st_day',
    start: DateTime(2026, 11, 11, 8),
    end: DateTime(2026, 11, 11, 17),
  ),
  makeReservation(
    id: 'arriving',
    guestName: 'Arriving Guest',
    start: DateTime(2026, 11, 14, 14),
    end: DateTime(2026, 11, 15, 12),
  ),
];

Finder statValue(String label, String value) => find.descendant(
  of: find.widgetWithText(StatCard, label),
  matching: find.text(value),
);

void main() {
  group('Reservation List', () {
    testWidgets('desktop shows status chips with counts', (tester) async {
      await pumpDesktop(
        tester,
        ReservationListScreen(gateway: FakeGateway(reservations: listData())),
      );

      expect(find.byType(AdminTable), findsOneWidget);
      expect(chipText('All'), findsOneWidget);
      expect(chipText('25'), findsOneWidget);
      expect(chipText('19'), findsOneWidget); // Reserved
      expect(chipText('3'), findsOneWidget); // Checked In
      expect(chipText('1'), findsOneWidget); // Completed
      expect(chipText('2'), findsOneWidget); // Cancelled
    });

    testWidgets('a status chip filters the table', (tester) async {
      await pumpDesktop(
        tester,
        ReservationListScreen(gateway: FakeGateway(reservations: listData())),
      );

      await tester.tap(chipText('Cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('Guest 05'), findsOneWidget);
      expect(find.text('Guest 06'), findsOneWidget);
      expect(find.text('Guest 07'), findsNothing);
      expect(find.text('Showing 1–2 of 2 reservations'), findsOneWidget);
    });

    testWidgets('20 rows per page with page controls', (tester) async {
      await pumpDesktop(
        tester,
        ReservationListScreen(gateway: FakeGateway(reservations: listData())),
      );

      // Default order: newest check-in first.
      expect(find.text('Showing 1–20 of 25 reservations'), findsOneWidget);
      expect(find.text('Guest 25'), findsOneWidget);
      expect(find.text('Guest 05'), findsNothing);

      // The page controls sit below the 20 rows, outside the 1000px-tall
      // test window: scroll the page (like a user would) until page "2" can
      // actually be tapped.
      final pageScroll = find
          .descendant(
            of: find.byType(DesktopPage),
            matching: find.byType(Scrollable),
          )
          .first;
      // hitTestable(): keep dragging until the button is on screen, not just
      // built.
      await tester.scrollUntilVisible(
        pageButton('2').hitTestable(),
        300,
        scrollable: pageScroll,
      );
      await tester.pumpAndSettle();
      expect(pageButton('2').hitTestable(), findsOneWidget);

      await tester.tap(pageButton('2'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 21–25 of 25 reservations'), findsOneWidget);
      expect(find.text('Guest 05'), findsOneWidget);
      expect(find.text('Guest 25'), findsNothing);
    });

    testWidgets('sorting by guest name toggles the order', (tester) async {
      await pumpDesktop(
        tester,
        ReservationListScreen(gateway: FakeGateway(reservations: listData())),
      );

      await tester.tap(find.text('GUEST'));
      await tester.pumpAndSettle();
      // A → Z: Guest 01 … Guest 20 on page 1.
      expect(find.text('Guest 01'), findsOneWidget);
      expect(find.text('Guest 25'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Guest 01')).dy,
        lessThan(tester.getTopLeft(find.text('Guest 02')).dy),
      );

      await tester.tap(find.text('GUEST'));
      await tester.pumpAndSettle();
      // Z → A: Guest 25 first, Guest 01 moves to page 2.
      expect(find.text('Guest 25'), findsOneWidget);
      expect(find.text('Guest 01'), findsNothing);
    });

    testWidgets('sorting by check-out works', (tester) async {
      await pumpDesktop(
        tester,
        ReservationListScreen(gateway: FakeGateway(reservations: listData())),
      );

      await tester.tap(find.text('CHECK-OUT'));
      await tester.pumpAndSettle();
      // Earliest check-out first.
      expect(find.text('Guest 01'), findsOneWidget);
      expect(find.text('Guest 25'), findsNothing);
    });

    testWidgets('empty state when there are no reservations', (tester) async {
      await pumpDesktop(tester, ReservationListScreen(gateway: FakeGateway()));

      expect(find.text('No reservations yet.'), findsOneWidget);
      expect(find.byType(AdminTable), findsNothing);
    });

    testWidgets('desktop error shows a friendly message and Retry works', (
      tester,
    ) async {
      final fake = FakeGateway(reservations: listData())..failLoads = true;
      await pumpDesktop(tester, ReservationListScreen(gateway: fake));

      expect(find.textContaining('Cannot reach PocketBase'), findsOneWidget);
      expect(find.textContaining('ClientException'), findsNothing);

      fake.failLoads = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminTable), findsOneWidget);
    });

    testWidgets('phone/tablet keeps the card list (no table)', (tester) async {
      await pumpMobile(
        tester,
        ReservationListScreen(
          gateway: FakeGateway(reservations: listData().take(3).toList()),
        ),
      );

      expect(find.byType(AdminTable), findsNothing);
      expect(find.byType(ReservationListCard), findsWidgets);
    });

    testWidgets('phone/tablet error shows Retry', (tester) async {
      final fake = FakeGateway(reservations: listData().take(3).toList())
        ..failLoads = true;
      await pumpMobile(tester, ReservationListScreen(gateway: fake));

      expect(find.textContaining('Cannot reach PocketBase'), findsOneWidget);
      fake.failLoads = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(ReservationListCard), findsWidgets);
    });
  });

  group('Calendar (desktop)', () {
    Future<void> pumpCalendar(WidgetTester tester) => pumpDesktop(
      tester,
      CalendarScreen(
        gateway: FakeGateway(reservations: calendarData()),
        clock: clock,
      ),
    );

    testWidgets('a multi-night stay shows on every day it touches', (
      tester,
    ) async {
      await pumpCalendar(tester);
      // Nov 10, 11, 12 and 13.
      expect(inGrid('Multi Guest'), findsNWidgets(4));
    });

    testWidgets('a Night Tour shows on both dates', (tester) async {
      await pumpCalendar(tester);
      expect(inGrid('Night Guest'), findsNWidgets(2));
    });

    testWidgets('more than 3 bookings in a day shows "+N more"', (
      tester,
    ) async {
      await pumpCalendar(tester);
      expect(inGrid('+2 more'), findsOneWidget);
      expect(inGrid('Busy 1'), findsOneWidget);
      expect(inGrid('Busy 4'), findsNothing); // 4th active booking hidden
      expect(inGrid('Busy Cancelled'), findsNothing); // cancelled go last
    });

    testWidgets('cancelled bookings are dimmed and listed last', (
      tester,
    ) async {
      await pumpCalendar(tester);

      final active = inGrid('Late Active');
      final cancelled = inGrid('Early Cancel');
      expect(
        tester.getTopLeft(active).dy,
        lessThan(tester.getTopLeft(cancelled).dy),
      );

      Opacity nearestOpacity(Finder f) => tester.widget<Opacity>(
        find.ancestor(of: f, matching: find.byType(Opacity)).first,
      );
      expect(nearestOpacity(cancelled).opacity, 0.5);
      expect(nearestOpacity(active).opacity, 1.0);
    });

    testWidgets('selected day panel lists that day\'s bookings', (
      tester,
    ) async {
      await pumpCalendar(tester);
      expect(find.text('Wednesday'), findsOneWidget); // Nov 11
      expect(find.text('Other reservations this month'), findsOneWidget);
      expect(find.text('Add New Reservation'), findsOneWidget);
    });
  });

  group('Dashboard (desktop)', () {
    testWidgets('four stats leave out Completed and Cancelled', (tester) async {
      await pumpDesktop(
        tester,
        DashboardScreen(
          gateway: FakeGateway(reservations: dashboardData()),
          clock: clock,
        ),
      );

      // Staying, Early Leaver and Arriving check in this month.
      expect(statValue('RESERVATIONS THIS MONTH', '3'), findsOneWidget);
      // Only the checked-in guest (not the one who left early).
      expect(statValue('STAYING NOW', '1'), findsOneWidget);
      expect(statValue('ARRIVING IN NEXT 7 DAYS', '1'), findsOneWidget);
      // One occupied unit out of 2 active units.
      expect(statValue('UNITS OCCUPIED NOW', '1 / 2'), findsOneWidget);
    });

    testWidgets('upcoming leaves out Completed and Cancelled', (tester) async {
      await pumpDesktop(
        tester,
        DashboardScreen(
          gateway: FakeGateway(reservations: dashboardData()),
          clock: clock,
        ),
      );

      expect(find.text('Upcoming Reservations'), findsOneWidget);
      expect(find.text('Staying Guest'), findsOneWidget);
      expect(find.text('Arriving Guest'), findsOneWidget);
      expect(find.text('Early Leaver'), findsNothing);
      expect(find.text('Cancelled Guest'), findsNothing);
    });

    testWidgets('no setup warning when configuration is complete', (
      tester,
    ) async {
      await pumpDesktop(
        tester,
        DashboardScreen(
          gateway: FakeGateway(reservations: dashboardData()),
          clock: clock,
        ),
      );
      expect(find.text('Resort setup needs attention'), findsNothing);
    });

    testWidgets('setup warning lists a missing rate', (tester) async {
      await pumpDesktop(
        tester,
        DashboardScreen(
          gateway: FakeGateway(
            reservations: dashboardData(),
            rates: [cottageOvernightRate, cottageDayRate], // no Night Tour
          ),
          clock: clock,
        ),
      );
      expect(find.text('Resort setup needs attention'), findsOneWidget);
      expect(find.textContaining('Night Tour has no rate'), findsOneWidget);
    });

    testWidgets('load error is friendly and Retry reloads', (tester) async {
      final fake = FakeGateway(reservations: dashboardData())..failLoads = true;
      await pumpDesktop(tester, DashboardScreen(gateway: fake, clock: clock));

      expect(find.textContaining('Cannot reach PocketBase'), findsOneWidget);
      fake.failLoads = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Staying Guest'), findsOneWidget);
    });
  });

  group('Responsive smoke tests (no overflow)', () {
    for (final width in [1024.0, 1280.0, 1440.0]) {
      testWidgets('desktop screens at ${width.toInt()}px', (tester) async {
        await pumpDesktop(
          tester,
          ReservationListScreen(gateway: FakeGateway(reservations: listData())),
          width: width,
        );
        expect(tester.takeException(), isNull);

        await pumpDesktop(
          tester,
          CalendarScreen(
            gateway: FakeGateway(reservations: calendarData()),
            clock: clock,
          ),
          width: width,
        );
        expect(tester.takeException(), isNull);

        await pumpDesktop(
          tester,
          DashboardScreen(
            gateway: FakeGateway(reservations: dashboardData()),
            clock: clock,
          ),
          width: width,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
