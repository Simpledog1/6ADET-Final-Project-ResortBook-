// Manage Resort → Unit Types and Units: the owner types their own unit
// types (Function Hall, Cabana, …) and adds units under them. Uses the fake
// gateway, so nothing is saved to a real PocketBase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/unit.dart';
import 'package:final_project/models/unit_type.dart';
import 'package:final_project/screens/add_reservation_screen.dart';
import 'package:final_project/screens/manage/unit_form.dart';
import 'package:final_project/screens/manage/unit_type_form.dart';
import 'package:final_project/theme/app_theme.dart';

import 'support/fake_gateway.dart';

// The demo data's second type (the first, Cottage, is in fake_gateway).
const villaType = UnitType(id: 'ut_villa', name: 'Villa', defaultCapacity: 6);

// A type the owner created themselves.
const functionHall = UnitType(
  id: 'ut_hall',
  name: 'Function Hall',
  defaultCapacity: 50,
);

/// Hosts [form] on its own page (like Manage Resort does) and records what
/// it pops. Tap "open" to show it; it can be opened again after closing.
Future<List<Object?>> pumpHost(
  WidgetTester tester,
  Widget Function() form,
) async {
  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: form(),
                      ),
                    ),
                  ),
                );
                results.add(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  return results;
}

Future<void> open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  final save = find.text('Save');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  group('Unit Types', () {
    testWidgets('the owner can type brand-new unit type names', (tester) async {
      final fake = FakeGateway(unitTypes: [cottageType, villaType]);
      final results = await pumpHost(
        tester,
        () => UnitTypeForm(
          otherNames: fake.unitTypes.map((t) => t.name).toList(),
          gateway: fake,
        ),
      );

      for (final (name, capacity) in [
        ('Function Hall', '50'),
        ('  Pool   Area ', '30'), // extra spaces are tidied up
        ('Gazebo', '8'),
      ]) {
        await open(tester);
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'e.g. Cottage, Villa, Function Hall',
          ),
          name,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Guests'),
          capacity,
        );
        await tapSave(tester);
      }

      expect(results, [true, true, true]);
      expect(fake.calls, [
        'createUnitType',
        'createUnitType',
        'createUnitType',
      ]);
      expect(fake.unitTypes.map((t) => t.name), [
        'Cottage', // demo data is kept
        'Villa',
        'Function Hall',
        'Pool Area',
        'Gazebo',
      ]);
      expect(fake.unitTypes[2].defaultCapacity, 50);
      expect(fake.unitTypes.last.isActive, isTrue);
    });

    testWidgets('a name that already exists is refused', (tester) async {
      final fake = FakeGateway(unitTypes: [cottageType, villaType]);
      await pumpHost(
        tester,
        () =>
            UnitTypeForm(otherNames: const ['Cottage', 'Villa'], gateway: fake),
      );
      await open(tester);

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'e.g. Cottage, Villa, Function Hall',
        ),
        'cottage',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Guests'), '4');
      await tapSave(tester);

      expect(find.textContaining('already exists'), findsOneWidget);
      expect(fake.calls, isEmpty);
    });

    testWidgets('an existing type can be renamed and deactivated', (
      tester,
    ) async {
      final fake = FakeGateway(unitTypes: [cottageType, villaType]);
      await pumpHost(
        tester,
        () => UnitTypeForm(
          existing: villaType,
          otherNames: const ['Cottage'],
          gateway: fake,
        ),
      );
      await open(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Villa'),
        'Private Villa',
      );
      final active = find.byType(Switch);
      await tester.ensureVisible(active);
      await tester.tap(active);
      await tester.pump();
      await tapSave(tester);

      expect(fake.calls, ['updateUnitType']);
      final saved = fake.unitTypes.firstWhere((t) => t.id == 'ut_villa');
      expect(saved.name, 'Private Villa');
      expect(saved.isActive, isFalse);
      expect(fake.unitTypes.first.name, 'Cottage'); // untouched
    });
  });

  group('Units under an owner-created type', () {
    Future<void> addUnit(WidgetTester tester, String name) async {
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Cottage 1'),
        name,
      );
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Function Hall').last);
      await tester.pumpAndSettle();
      await tapSave(tester);
    }

    testWidgets('several units can be added to the custom type', (
      tester,
    ) async {
      final fake = FakeGateway(
        unitTypes: [cottageType, villaType, functionHall],
      );
      final results = await pumpHost(
        tester,
        () => UnitForm(unitTypes: fake.unitTypes, gateway: fake),
      );

      await addUnit(tester, 'Main Hall');
      await addUnit(tester, 'Garden Hall');

      expect(results, [true, true]);
      expect(fake.calls, ['createUnit', 'createUnit']);
      final halls = fake.units.where((u) => u.unitTypeId == 'ut_hall');
      expect(halls.map((u) => u.name), ['Main Hall', 'Garden Hall']);
      // Capacity is filled in from the type's default (50).
      expect(halls.every((u) => u.capacity == 50), isTrue);
      // The demo units are still there.
      expect(fake.units.take(2).map((u) => u.name), ['Cottage A', 'Cottage B']);
    });

    testWidgets('inactive types are not offered for new units', (tester) async {
      const oldType = UnitType(id: 'ut_old', name: 'Old Hut', isActive: false);
      final fake = FakeGateway(unitTypes: [cottageType, functionHall, oldType]);
      await pumpHost(
        tester,
        () => UnitForm(unitTypes: fake.unitTypes, gateway: fake),
      );
      await open(tester);

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(find.text('Function Hall'), findsWidgets);
      expect(find.textContaining('Old Hut'), findsNothing);
    });

    testWidgets('new custom units appear in Add Reservation', (tester) async {
      final fake = FakeGateway(
        unitTypes: [cottageType, villaType, functionHall],
      );
      await pumpHost(
        tester,
        () => UnitForm(unitTypes: fake.unitTypes, gateway: fake),
      );
      await addUnit(tester, 'Main Hall');

      // Add Reservation reads the units from the same data source.
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(), // a fresh app, not the host page
          theme: AppTheme.lightTheme,
          home: AddReservationScreen(gateway: fake),
        ),
      );
      await tester.pumpAndSettle();
      final units = find.byType(DropdownButtonFormField<Unit>);
      await tester.ensureVisible(units);
      await tester.tap(units);
      await tester.pumpAndSettle();

      expect(find.text('Main Hall · Function Hall · up to 50'), findsWidgets);
      expect(find.text('Cottage A · up to 4'), findsWidgets);
    });
  });
}
