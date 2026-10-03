import '../models/rate.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';
import '../models/unit_type.dart';

/// A unit type + stay type combination that has no configured rate.
class MissingRate {
  final UnitType unitType;
  final StayType stayType;

  const MissingRate({required this.unitType, required this.stayType});

  String get label => '${unitType.name} — ${stayType.name} has no rate';
}

/// Which Manage Resort section a checklist item points to.
enum ConfigSection { unitTypes, units, stayTypes, rates }

/// One item of the Manage Resort setup checklist.
class ChecklistIssue {
  final String message;
  final ConfigSection section;

  const ChecklistIssue({required this.message, required this.section});
}

/// Validation and safety rules for resort configuration.
/// Pure Dart (no Flutter, no network) so they can be unit tested.
class ConfigRules {
  ConfigRules._();

  // ── Names ──────────────────────────────────────────────────────────────

  /// Trims and collapses repeated spaces: "  Family   Cottage " → "Family Cottage".
  static String normalizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Name is required and must not match (case-insensitively) any of
  /// [existingNames]. Pass the names of the OTHER records only.
  static String? validateName(
    String? value, {
    required Iterable<String> existingNames,
    required String itemLabel, // e.g. "unit type"
  }) {
    final name = normalizeName(value ?? '');
    if (name.isEmpty) return 'Name is required.';
    final lower = name.toLowerCase();
    for (final other in existingNames) {
      if (normalizeName(other).toLowerCase() == lower) {
        return 'A $itemLabel named "$name" already exists.';
      }
    }
    return null;
  }

  // ── Numbers ────────────────────────────────────────────────────────────

  /// Required whole number of at least 1.
  static String? validateCapacity(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Capacity is required.';
    final number = int.tryParse(text);
    if (number == null) return 'Enter a whole number.';
    if (number < 1) return 'Capacity must be at least 1.';
    return null;
  }

  /// Optional whole number (empty means 0).
  static String? validateSortOrder(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (int.tryParse(text) == null) return 'Enter a whole number.';
    return null;
  }

  static int parseSortOrder(String? value) =>
      int.tryParse((value ?? '').trim()) ?? 0;

  /// Required, 0 or more, at most 2 decimal places (e.g. 2500 or 1250.50).
  static String? validatePrice(String? value) {
    final text = (value ?? '').trim().replaceAll(',', '');
    if (text.isEmpty) return 'Price is required.';
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
      if (RegExp(r'^\d+\.\d{3,}$').hasMatch(text)) {
        return 'Use at most 2 decimal places.';
      }
      return 'Enter a valid amount, 0 or more.';
    }
    return null;
  }

  static double parsePrice(String value) =>
      double.parse(value.trim().replaceAll(',', ''));

  // ── Stay type times ────────────────────────────────────────────────────

  static bool isValidTime(String hhmm) =>
      RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(hhmm);

  static int minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Rules that keep a stay type compatible with the booking logic.
  /// Returns the first problem, or null when the configuration is valid.
  static String? validateStayTimes({
    required String checkInTime,
    required String checkOutTime,
    required bool endsNextDay,
    required bool allowMultipleNights,
    required PricingBasis pricingBasis,
  }) {
    if (!isValidTime(checkInTime)) return 'Choose a check-in time.';
    if (!isValidTime(checkOutTime)) return 'Choose a check-out time.';

    if (!endsNextDay &&
        minutesOf(checkOutTime) <= minutesOf(checkInTime)) {
      return 'For a same-day stay, check-out must be after check-in. '
          'Turn on "Ends next day" if guests leave the following day.';
    }
    if (allowMultipleNights && !endsNextDay) {
      return 'Multiple nights requires "Ends next day".';
    }
    if (pricingBasis == PricingBasis.perNight && !endsNextDay) {
      return 'Per-night pricing requires "Ends next day".';
    }
    return null;
  }

  // ── Deletion safety ────────────────────────────────────────────────────

  /// A unit type can be deleted only when no unit (active or inactive)
  /// references it.
  static bool canDeleteUnitType(int unitCount) => unitCount == 0;

  /// A unit can be deleted only when no reservation references it —
  /// including cancelled, past and test reservations.
  static bool canDeleteUnit(int reservationCount) => reservationCount == 0;

  /// A stay type can be deleted only when no reservation references it.
  static bool canDeleteStayType(int reservationCount) =>
      reservationCount == 0;

  // ── Deactivation ───────────────────────────────────────────────────────

  /// Active units that belong to [unitTypeId].
  static List<Unit> activeUnitsOfType(String unitTypeId, Iterable<Unit> units) {
    return units
        .where((u) => u.unitTypeId == unitTypeId && u.isActive)
        .toList();
  }

  /// Units to deactivate together with a unit type. Empty unless the user
  /// explicitly ticked "Also deactivate these units".
  static List<Unit> unitsToDeactivateWithType({
    required String unitTypeId,
    required Iterable<Unit> units,
    required bool alsoDeactivateUnits,
  }) {
    if (!alsoDeactivateUnits) return const [];
    return activeUnitsOfType(unitTypeId, units);
  }

  /// True when [stayType] is the only active stay type left.
  static bool isLastActiveStayType(
    StayType stayType,
    Iterable<StayType> allStayTypes,
  ) {
    if (!stayType.isActive) return false;
    final active = allStayTypes.where((s) => s.isActive).toList();
    return active.length == 1 && active.first.id == stayType.id;
  }

  // ── Rates & checklist ──────────────────────────────────────────────────

  static Rate? rateFor(
    Iterable<Rate> rates,
    String unitTypeId,
    String stayTypeId,
  ) {
    for (final rate in rates) {
      if (rate.unitTypeId == unitTypeId && rate.stayTypeId == stayTypeId) {
        return rate;
      }
    }
    return null;
  }

  /// Active unit type × active stay type combinations without a rate.
  static List<MissingRate> missingRates({
    required Iterable<UnitType> unitTypes,
    required Iterable<StayType> stayTypes,
    required Iterable<Rate> rates,
  }) {
    final result = <MissingRate>[];
    for (final type in unitTypes.where((t) => t.isActive)) {
      for (final stay in stayTypes.where((s) => s.isActive)) {
        if (rateFor(rates, type.id, stay.id) == null) {
          result.add(MissingRate(unitType: type, stayType: stay));
        }
      }
    }
    return result;
  }

  /// Problems that stop (or will stop) reservations from being created.
  static List<ChecklistIssue> setupChecklist({
    required List<UnitType> unitTypes,
    required List<Unit> units,
    required List<StayType> stayTypes,
    required List<Rate> rates,
  }) {
    final issues = <ChecklistIssue>[];

    if (!stayTypes.any((s) => s.isActive)) {
      issues.add(const ChecklistIssue(
        message: 'No active stay types — new reservations cannot be created.',
        section: ConfigSection.stayTypes,
      ));
    }

    if (!units.any((u) => u.isActive)) {
      issues.add(const ChecklistIssue(
        message: 'No active units — new reservations cannot be created.',
        section: ConfigSection.units,
      ));
    }

    for (final unit in units.where((u) => u.unitTypeId.isEmpty)) {
      issues.add(ChecklistIssue(
        message: '${unit.name} has no unit type.',
        section: ConfigSection.units,
      ));
    }

    final typesById = {for (final t in unitTypes) t.id: t};
    for (final unit in units.where((u) => u.isActive)) {
      final type = typesById[unit.unitTypeId];
      if (type != null && !type.isActive) {
        issues.add(ChecklistIssue(
          message: '${unit.name} is active but uses the inactive unit type '
              '${type.name}.',
          section: ConfigSection.units,
        ));
      }
    }

    for (final missing in missingRates(
      unitTypes: unitTypes,
      stayTypes: stayTypes,
      rates: rates,
    )) {
      issues.add(ChecklistIssue(
        message: missing.label,
        section: ConfigSection.rates,
      ));
    }

    return issues;
  }
}
