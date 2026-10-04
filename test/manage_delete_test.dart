// Safe deletion in Manage Resort → Unit Types and Units:
// * a unit type can be deleted only when no unit uses it;
// * a unit can be deleted only when it has no reservations;
// * both ask for confirmation, and the demo records stay untouched.
// Uses the fake gateway (same delete rules as ConfigService).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/unit.dart';
import 'package:final_project/models/unit_type.dart';
import 'package:final_project/screens/manage/unit_types_screen.dart';
import 'package:final_project/screens/manage/units_screen.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:final_project/widgets/app_card.dart';
import 'package:final_project/widgets/responsive.dart';

import 'support/fake_gateway.dart';

// Demo data: Cottage (Cottage A, Cottage B) and Villa (Villa 1).
const villaType = UnitType(id: 'ut_villa', name: 'Villa', defaultCapacity: 6);
const villa1 = Unit(
  id: 'unit_villa1',
  name: 'Villa 1',
  unitTypeId: 'ut_villa',
  unitType: villaType,
  capacity: 6,
);

// A type the owner added and never used.
const gazebo = UnitType(id: 'ut_gazebo', name: 'Gazebo', defaultCapacity: 8);

FakeGateway demoGateway() => FakeGateway(
  unitTypes: [cottageType, villaType, gazebo],
  units: [cottageA, cottageB, villa1],
  // Cottage A has reservation history.
  reservations: [
    makeReservation(
      start: DateTime(2026, 11, 10, 14),
      end: DateTime(2026, 11, 11, 12),
    ),
  ],
);

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  bool desktop = false,
}) async {
  if (desktop) {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: desktop ? DesktopShellScope(child: screen) : screen,
    ),
  );
  await tester.pumpAndSettle();
}

/// Phone / tablet: opens the "⋮" menu on the card named [name].
Future<void> openActions(WidgetTester tester, String name) async {
  final card = find.ancestor(
    of: find.text(name),
    matching: find.byType(AppCard),
  );
  final menu = find.descendant(
    of: card,
    matching: find.byType(PopupMenuButton<int>),
  );
  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
}

Future<void> tapMenuDelete(WidgetTester tester) async {
  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();
}

Future<void> confirmDelete(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
  await tester.pumpAndSettle();
}

void main() {
  group('Unit Types', () {
    testWidgets('an unused unit type is deleted after confirming', (
      tester,
    ) async {
      final fake = demoGateway();
      await pumpScreen(tester, UnitTypesScreen(gateway: fake));

      // Cancel first: nothing happens.
      await openActions(tester, 'Gazebo');
      await tapMenuDelete(tester);
      expect(find.text('Delete Gazebo?'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);

      // Then confirm.
      await openActions(tester, 'Gazebo');
      await tapMenuDelete(tester);
      await confirmDelete(tester);

      expect(fake.calls, ['deleteUnitType']);
      expect(find.text('Gazebo deleted.'), findsOneWidget);
      expect(find.text('Gazebo'), findsNothing);
      // The demo types are still there.
      expect(fake.unitTypes.map((t) => t.name), ['Cottage', 'Villa']);
      expect(find.text('Cottage'), findsOneWidget);
      expect(find.text('Villa'), findsOneWidget);
    });

    testWidgets('a unit type that has units cannot be deleted', (tester) async {
      final fake = demoGateway();
      await pumpScreen(tester, UnitTypesScreen(gateway: fake));

      await openActions(tester, 'Cottage');
      expect(
        find.textContaining('must have no units before it can be deleted'),
        findsOneWidget,
      );
      await tapMenuDelete(tester); // disabled: no confirmation dialog
      expect(find.text('Delete Cottage?'), findsNothing);
      expect(fake.calls, isEmpty);
      expect(fake.unitTypes.map((t) => t.name), contains('Cottage'));
    });

    testWidgets('the delete is checked again before it happens', (
      tester,
    ) async {
      final fake = demoGateway();
      await pumpScreen(tester, UnitTypesScreen(gateway: fake));

      // Someone adds a Gazebo unit after the list was loaded.
      fake.units = [
        ...fake.units,
        const Unit(id: 'unit_g1', name: 'Gazebo 1', unitTypeId: 'ut_gazebo'),
      ];
      await openActions(tester, 'Gazebo');
      await tapMenuDelete(tester);
      await confirmDelete(tester);

      expect(fake.calls, ['deleteUnitType']);
      expect(
        find.textContaining('must have no units before it can be deleted'),
        findsOneWidget,
      );
      expect(fake.unitTypes.map((t) => t.id), contains('ut_gazebo'));
    });

    testWidgets('desktop: delete from the table', (tester) async {
      final fake = demoGateway();
      await pumpScreen(tester, UnitTypesScreen(gateway: fake), desktop: true);

      // Only Gazebo's Delete button is enabled; the others explain why not.
      expect(find.byTooltip('Delete'), findsOneWidget);
      expect(
        find.byTooltip(
          'Used by 2 units. A unit type must have no units before it can be '
          'deleted: move its units to another type or delete them first, or '
          'deactivate this type instead.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await confirmDelete(tester);

      expect(fake.calls, ['deleteUnitType']);
      expect(fake.unitTypes.map((t) => t.name), ['Cottage', 'Villa']);
    });
  });

  group('Units', () {
    testWidgets('a unit without reservations is deleted after confirming', (
      tester,
    ) async {
      final fake = demoGateway();
      await pumpScreen(tester, UnitsScreen(gateway: fake));

      await openActions(tester, 'Cottage B');
      await tapMenuDelete(tester);
      expect(find.text('Delete Cottage B?'), findsOneWidget);
      await confirmDelete(tester);

      expect(fake.calls, ['deleteUnit']);
      expect(find.text('Cottage B deleted.'), findsOneWidget);
      expect(fake.units.map((u) => u.name), ['Cottage A', 'Villa 1']);
      expect(fake.reservations, hasLength(1)); // history untouched
    });

    testWidgets('a unit with reservations cannot be deleted', (tester) async {
      final fake = demoGateway();
      await pumpScreen(tester, UnitsScreen(gateway: fake));

      await openActions(tester, 'Cottage A');
      expect(find.textContaining('reservation history'), findsOneWidget);
      await tapMenuDelete(tester); // disabled: no confirmation dialog
      expect(find.text('Delete Cottage A?'), findsNothing);
      expect(fake.calls, isEmpty);
      expect(fake.units.map((u) => u.name), [
        'Cottage A',
        'Cottage B',
        'Villa 1',
      ]);
    });
  });
}
