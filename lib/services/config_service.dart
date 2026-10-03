import 'pocketbase_service.dart';
import '../models/rate.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';
import '../models/unit_type.dart';

/// Resort configuration: units, unit types, stay types and rates.
///
/// Items are deactivated (`isActive = false`) rather than deleted, so
/// existing reservations keep pointing at real records.
class ConfigService {
  ConfigService._();

  static final _pb = PocketBaseService.pb;

  static String? _activeFilter(bool activeOnly) =>
      activeOnly ? 'isActive = true' : null;

  // ── Unit types ─────────────────────────────────────────────────────────

  static Future<List<UnitType>> getUnitTypes({bool activeOnly = false}) async {
    final records = await _pb
        .collection('unit_types')
        .getFullList(sort: 'sortOrder,name', filter: _activeFilter(activeOnly));
    return records.map(UnitType.fromRecord).toList();
  }

  static Future<UnitType> createUnitType(UnitType type) async {
    final record =
        await _pb.collection('unit_types').create(body: type.toBody());
    return UnitType.fromRecord(record);
  }

  static Future<UnitType> updateUnitType(UnitType type) async {
    final record = await _pb
        .collection('unit_types')
        .update(type.id, body: type.toBody());
    return UnitType.fromRecord(record);
  }

  static Future<void> setUnitTypeActive(String id, bool isActive) async {
    await _pb.collection('unit_types').update(id, body: {'isActive': isActive});
  }

  // ── Units ──────────────────────────────────────────────────────────────

  static Future<List<Unit>> getUnits({bool activeOnly = false}) async {
    final records = await _pb
        .collection('units')
        .getFullList(
          sort: 'sortOrder,name',
          filter: _activeFilter(activeOnly),
          expand: 'unitType',
        );
    return records.map(Unit.fromRecord).toList();
  }

  static Future<Unit> createUnit(Unit unit) async {
    final record = await _pb
        .collection('units')
        .create(body: unit.toBody(), expand: 'unitType');
    return Unit.fromRecord(record);
  }

  static Future<Unit> updateUnit(Unit unit) async {
    final record = await _pb
        .collection('units')
        .update(unit.id, body: unit.toBody(), expand: 'unitType');
    return Unit.fromRecord(record);
  }

  static Future<void> setUnitActive(String id, bool isActive) async {
    await _pb.collection('units').update(id, body: {'isActive': isActive});
  }

  // ── Stay types ─────────────────────────────────────────────────────────

  static Future<List<StayType>> getStayTypes({bool activeOnly = false}) async {
    final records = await _pb
        .collection('stay_types')
        .getFullList(sort: 'sortOrder,name', filter: _activeFilter(activeOnly));
    return records.map(StayType.fromRecord).toList();
  }

  static Future<StayType> createStayType(StayType stayType) async {
    final record =
        await _pb.collection('stay_types').create(body: stayType.toBody());
    return StayType.fromRecord(record);
  }

  static Future<StayType> updateStayType(StayType stayType) async {
    final record = await _pb
        .collection('stay_types')
        .update(stayType.id, body: stayType.toBody());
    return StayType.fromRecord(record);
  }

  static Future<void> setStayTypeActive(String id, bool isActive) async {
    await _pb.collection('stay_types').update(id, body: {'isActive': isActive});
  }

  // ── Rates (₱ per unit type + stay type) ────────────────────────────────

  static Future<List<Rate>> getRates() async {
    final records = await _pb.collection('rates').getFullList();
    return records.map(Rate.fromRecord).toList();
  }

  /// The rate for a unit type + stay type, or null if none is configured.
  static Future<Rate?> findRate({
    required String unitTypeId,
    required String stayTypeId,
  }) async {
    if (unitTypeId.isEmpty || stayTypeId.isEmpty) return null;
    final result = await _pb
        .collection('rates')
        .getList(
          perPage: 1,
          filter: _pb.filter(
            'unitType = {:ut} && stayType = {:st}',
            {'ut': unitTypeId, 'st': stayTypeId},
          ),
        );
    return result.items.isEmpty ? null : Rate.fromRecord(result.items.first);
  }

  /// Creates or updates the single rate for a unit type + stay type.
  static Future<Rate> saveRate({
    required String unitTypeId,
    required String stayTypeId,
    required double price,
  }) async {
    final existing = await findRate(
      unitTypeId: unitTypeId,
      stayTypeId: stayTypeId,
    );
    final body = {
      'unitType': unitTypeId,
      'stayType': stayTypeId,
      'price': price,
    };
    final record = existing == null
        ? await _pb.collection('rates').create(body: body)
        : await _pb.collection('rates').update(existing.id, body: body);
    return Rate.fromRecord(record);
  }

  static Future<void> deleteRate(String id) async {
    await _pb.collection('rates').delete(id);
  }
}
