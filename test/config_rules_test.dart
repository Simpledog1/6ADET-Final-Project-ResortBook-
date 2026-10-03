import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/logic/config_rules.dart';
import 'package:final_project/models/rate.dart';
import 'package:final_project/models/stay_type.dart';
import 'package:final_project/models/unit.dart';
import 'package:final_project/models/unit_type.dart';

const cottage = UnitType(id: 'ut_cottage', name: 'Cottage', defaultCapacity: 10);
const villa = UnitType(id: 'ut_villa', name: 'Villa', defaultCapacity: 6);
const oldType = UnitType(id: 'ut_old', name: 'Old Hut', isActive: false);

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
const nightTour = StayType(
  id: 'st_night',
  name: 'Night Tour',
  checkInTime: '19:00',
  checkOutTime: '06:00',
  endsNextDay: true,
);

void main() {
  group('names', () {
    test('normalizes whitespace', () {
      expect(ConfigRules.normalizeName('  Family   Cottage '), 'Family Cottage');
    });

    test('duplicate unit type names are rejected (case-insensitive)', () {
      expect(
        ConfigRules.validateName(
          '  cottage ',
          existingNames: ['Cottage', 'Villa'],
          itemLabel: 'unit type',
        ),
        contains('already exists'),
      );
    });

    test('duplicate unit names are rejected', () {
      expect(
        ConfigRules.validateName(
          'Cottage 1',
          existingNames: ['cottage   1', 'Cottage 2'],
          itemLabel: 'unit',
        ),
        isNotNull,
      );
    });

    test('duplicate stay type names are rejected', () {
      expect(
        ConfigRules.validateName(
          'OVERNIGHT',
          existingNames: ['Overnight', 'Day Tour'],
          itemLabel: 'stay type',
        ),
        isNotNull,
      );
    });

    test('a unique name passes and an empty name fails', () {
      expect(
        ConfigRules.validateName(
          'Pavilion',
          existingNames: ['Cottage'],
          itemLabel: 'unit type',
        ),
        isNull,
      );
      expect(
        ConfigRules.validateName(
          '   ',
          existingNames: const [],
          itemLabel: 'unit type',
        ),
        isNotNull,
      );
    });
  });

  group('capacity, sort order and price', () {
    test('capacity must be a whole number of at least 1', () {
      expect(ConfigRules.validateCapacity('4'), isNull);
      expect(ConfigRules.validateCapacity('0'), isNotNull);
      expect(ConfigRules.validateCapacity(''), isNotNull);
      expect(ConfigRules.validateCapacity('2.5'), isNotNull);
    });

    test('sort order is optional but must be a whole number', () {
      expect(ConfigRules.validateSortOrder(''), isNull);
      expect(ConfigRules.validateSortOrder('3'), isNull);
      expect(ConfigRules.validateSortOrder('x'), isNotNull);
      expect(ConfigRules.parseSortOrder(''), 0);
    });

    test('price is required, 0 or more, at most 2 decimals', () {
      expect(ConfigRules.validatePrice('2500'), isNull);
      expect(ConfigRules.validatePrice('0'), isNull);
      expect(ConfigRules.validatePrice('1250.50'), isNull);
      expect(ConfigRules.validatePrice('1,250.5'), isNull);
      expect(ConfigRules.validatePrice(''), isNotNull);
      expect(ConfigRules.validatePrice('-5'), isNotNull);
      expect(ConfigRules.validatePrice('12.345'), contains('2 decimal'));
      expect(ConfigRules.validatePrice('abc'), isNotNull);
      expect(ConfigRules.parsePrice('1,250.50'), 1250.5);
    });
  });

  group('stay type times', () {
    String? check({
      String inTime = '08:00',
      String outTime = '17:00',
      bool nextDay = false,
      bool multi = false,
      PricingBasis basis = PricingBasis.perStay,
    }) {
      return ConfigRules.validateStayTimes(
        checkInTime: inTime,
        checkOutTime: outTime,
        endsNextDay: nextDay,
        allowMultipleNights: multi,
        pricingBasis: basis,
      );
    }

    test('default stay types are valid', () {
      expect(check(), isNull); // Day Tour
      expect(
        check(
          inTime: '14:00',
          outTime: '12:00',
          nextDay: true,
          multi: true,
          basis: PricingBasis.perNight,
        ),
        isNull,
      ); // Overnight
      expect(check(inTime: '19:00', outTime: '06:00', nextDay: true), isNull);
    });

    test('same-day stay needs check-out after check-in', () {
      expect(check(inTime: '17:00', outTime: '08:00'), isNotNull);
      expect(check(inTime: '08:00', outTime: '08:00'), isNotNull);
    });

    test('multiple nights requires ends next day', () {
      expect(check(multi: true), isNotNull);
    });

    test('per-night pricing requires ends next day', () {
      expect(check(basis: PricingBasis.perNight), isNotNull);
      // A single-night stay may still be priced per night.
      expect(
        check(
          inTime: '19:00',
          outTime: '06:00',
          nextDay: true,
          basis: PricingBasis.perNight,
        ),
        isNull,
      );
    });

    test('times must be chosen', () {
      expect(check(inTime: ''), isNotNull);
      expect(check(outTime: '25:00'), isNotNull);
    });
  });

  group('deletion safety', () {
    test('unit type: only when no unit uses it', () {
      expect(ConfigRules.canDeleteUnitType(0), isTrue);
      expect(ConfigRules.canDeleteUnitType(1), isFalse);
    });

    test('unit: only when no reservation (any status) uses it', () {
      expect(ConfigRules.canDeleteUnit(0), isTrue);
      expect(ConfigRules.canDeleteUnit(1), isFalse); // e.g. one cancelled
    });

    test('stay type: only when no reservation uses it', () {
      expect(ConfigRules.canDeleteStayType(0), isTrue);
      expect(ConfigRules.canDeleteStayType(3), isFalse);
    });
  });

  group('deactivation', () {
    const units = [
      Unit(id: 'u1', name: 'Cottage 1', unitTypeId: 'ut_cottage', capacity: 10),
      Unit(id: 'u2', name: 'Cottage 2', unitTypeId: 'ut_cottage', capacity: 10),
      Unit(
        id: 'u3',
        name: 'Cottage 3',
        unitTypeId: 'ut_cottage',
        capacity: 10,
        isActive: false,
      ),
      Unit(id: 'u4', name: 'Villa 1', unitTypeId: 'ut_villa', capacity: 6),
    ];

    test('counts only the active units of the type', () {
      expect(ConfigRules.activeUnitsOfType('ut_cottage', units), hasLength(2));
    });

    test('units are deactivated only when explicitly requested', () {
      expect(
        ConfigRules.unitsToDeactivateWithType(
          unitTypeId: 'ut_cottage',
          units: units,
          alsoDeactivateUnits: false,
        ),
        isEmpty,
      );
      final chosen = ConfigRules.unitsToDeactivateWithType(
        unitTypeId: 'ut_cottage',
        units: units,
        alsoDeactivateUnits: true,
      );
      expect(chosen.map((u) => u.id), ['u1', 'u2']);
    });

    test('detects the last active stay type', () {
      const inactiveDay = StayType(
        id: 'st_day',
        name: 'Day Tour',
        checkInTime: '08:00',
        checkOutTime: '17:00',
        isActive: false,
      );
      expect(
        ConfigRules.isLastActiveStayType(overnight, [overnight, inactiveDay]),
        isTrue,
      );
      expect(
        ConfigRules.isLastActiveStayType(overnight, [overnight, dayTour]),
        isFalse,
      );
    });
  });

  group('rates and checklist', () {
    const rates = [
      Rate(id: 'r1', unitTypeId: 'ut_cottage', stayTypeId: 'st_overnight', price: 2500),
      Rate(id: 'r2', unitTypeId: 'ut_cottage', stayTypeId: 'st_day', price: 800),
      Rate(id: 'r3', unitTypeId: 'ut_villa', stayTypeId: 'st_overnight', price: 4000),
    ];

    test('lists each missing active combination', () {
      final missing = ConfigRules.missingRates(
        unitTypes: const [cottage, villa, oldType],
        stayTypes: const [overnight, dayTour, nightTour],
        rates: rates,
      );
      expect(
        missing.map((m) => m.label),
        [
          'Cottage — Night Tour has no rate',
          'Villa — Day Tour has no rate',
          'Villa — Night Tour has no rate',
        ],
      ); // inactive "Old Hut" is ignored
    });

    test('checklist flags setup problems', () {
      final issues = ConfigRules.setupChecklist(
        unitTypes: const [cottage, oldType],
        units: const [
          Unit(id: 'u1', name: 'Cottage 1', unitTypeId: 'ut_cottage'),
          Unit(id: 'u2', name: 'Hut 1', unitTypeId: 'ut_old'),
          Unit(id: 'u3', name: 'Mystery Unit'),
        ],
        stayTypes: const [],
        rates: const [],
      );
      final messages = issues.map((i) => i.message).toList();
      expect(messages, contains(startsWith('No active stay types')));
      expect(messages, contains('Mystery Unit has no unit type.'));
      expect(messages, contains(contains('Hut 1 is active but uses the inactive')));
    });

    test('a complete setup has no issues', () {
      final issues = ConfigRules.setupChecklist(
        unitTypes: const [cottage],
        units: const [
          Unit(id: 'u1', name: 'Cottage 1', unitTypeId: 'ut_cottage'),
        ],
        stayTypes: const [overnight, dayTour],
        rates: rates,
      );
      expect(issues, isEmpty);
    });
  });
}
