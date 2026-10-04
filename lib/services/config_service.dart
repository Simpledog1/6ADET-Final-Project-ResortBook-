import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_service.dart';
import '../models/rate.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';
import '../models/unit_type.dart';

/// Thrown when a guarded delete is refused because the record is in use.
class ConfigInUseException implements Exception {
  final String message;
  const ConfigInUseException(this.message);

  @override
  String toString() => message;
}

/// How reservations use units and stay types (for counts and delete checks).
class ReservationUsage {
  /// All reservations per unit id (any status, including cancelled).
  final Map<String, int> totalByUnit;

  /// Non-cancelled reservations per unit id that haven't ended yet.
  final Map<String, int> upcomingByUnit;

  /// Largest guest count among a unit's upcoming reservations.
  final Map<String, int> maxUpcomingGuestsByUnit;

  /// All reservations per stay type id (any status).
  final Map<String, int> totalByStayType;

  const ReservationUsage({
    required this.totalByUnit,
    required this.upcomingByUnit,
    required this.maxUpcomingGuestsByUnit,
    required this.totalByStayType,
  });

  int unitTotal(String unitId) => totalByUnit[unitId] ?? 0;
  int unitUpcoming(String unitId) => upcomingByUnit[unitId] ?? 0;
  int unitMaxUpcomingGuests(String unitId) =>
      maxUpcomingGuestsByUnit[unitId] ?? 0;
  int stayTypeTotal(String stayTypeId) => totalByStayType[stayTypeId] ?? 0;
}

/// Resort configuration: units, unit types, stay types and rates.
///
/// Items are deactivated (`isActive = false`) rather than deleted, so
/// existing reservations keep pointing at real records. Deletes are guarded:
/// they re-check usage on the server right before deleting, and they never
/// touch reservation records or their snapshot fields.
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
    final record = await _pb
        .collection('unit_types')
        .create(body: type.toBody());
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
    final record = await _pb
        .collection('stay_types')
        .create(body: stayType.toBody());
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
          filter: _pb.filter('unitType = {:ut} && stayType = {:st}', {
            'ut': unitTypeId,
            'st': stayTypeId,
          }),
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

  // ── Usage & guarded deletes (Stage 4) ──────────────────────────────────

  /// Number of records in [collection] matching [filter].
  static Future<int> _count(String collection, String filter) async {
    final result = await _pb
        .collection(collection)
        .getList(page: 1, perPage: 1, filter: filter, fields: 'id');
    return result.totalItems;
  }

  static Future<int> countUnitsOfType(String unitTypeId) {
    return _count('units', _pb.filter('unitType = {:id}', {'id': unitTypeId}));
  }

  /// Every reservation of the unit, including cancelled and past ones.
  static Future<int> countReservationsForUnit(String unitId) {
    return _count('reservations', _pb.filter('unit = {:id}', {'id': unitId}));
  }

  /// Every reservation that used the stay type, any status.
  static Future<int> countReservationsForStayType(String stayTypeId) {
    return _count(
      'reservations',
      _pb.filter('stayType = {:id}', {'id': stayTypeId}),
    );
  }

  /// Loads only the reservation fields needed to count usage.
  static Future<ReservationUsage> getReservationUsage() async {
    final records = await _pb
        .collection('reservations')
        .getFullList(fields: 'id,unit,stayType,endAt,status,guestCount');

    final now = DateTime.now();
    final totalByUnit = <String, int>{};
    final upcomingByUnit = <String, int>{};
    final maxGuests = <String, int>{};
    final totalByStayType = <String, int>{};

    for (final record in records) {
      final unitId = record.getStringValue('unit');
      final stayTypeId = record.getStringValue('stayType');
      final status = record.getStringValue('status').toLowerCase();
      final endAt = DateTime.tryParse(record.getStringValue('endAt'));
      final guests = record.getIntValue('guestCount');

      if (unitId.isNotEmpty) {
        totalByUnit[unitId] = (totalByUnit[unitId] ?? 0) + 1;
        final isUpcoming =
            !status.contains('cancel') && endAt != null && endAt.isAfter(now);
        if (isUpcoming) {
          upcomingByUnit[unitId] = (upcomingByUnit[unitId] ?? 0) + 1;
          if (guests > (maxGuests[unitId] ?? 0)) maxGuests[unitId] = guests;
        }
      }
      if (stayTypeId.isNotEmpty) {
        totalByStayType[stayTypeId] = (totalByStayType[stayTypeId] ?? 0) + 1;
      }
    }

    return ReservationUsage(
      totalByUnit: totalByUnit,
      upcomingByUnit: upcomingByUnit,
      maxUpcomingGuestsByUnit: maxGuests,
      totalByStayType: totalByStayType,
    );
  }

  /// Deactivates a unit type and, only when the user asked for it, the
  /// listed units. Units are never deleted; reservations are not touched.
  static Future<void> deactivateUnitType(
    String unitTypeId, {
    List<String> alsoDeactivateUnitIds = const [],
  }) async {
    await setUnitTypeActive(unitTypeId, false);
    for (final unitId in alsoDeactivateUnitIds) {
      await setUnitActive(unitId, false);
    }
  }

  static Future<void> _deleteRatesWhere(String filter) async {
    final rates = await _pb.collection('rates').getFullList(filter: filter);
    for (final rate in rates) {
      await _pb.collection('rates').delete(rate.id);
    }
  }

  /// Deletes a unit type only if no unit (active or inactive) uses it.
  /// Its rates are removed explicitly first. Reservations keep their own
  /// name/price snapshots, so they are unaffected.
  static Future<void> deleteUnitType(String unitTypeId) async {
    final units = await countUnitsOfType(unitTypeId);
    if (units > 0) {
      throw ConfigInUseException(
        'This unit type is used by $units unit${units == 1 ? '' : 's'} and '
        'cannot be deleted. Deactivate it instead.',
      );
    }
    await _deleteRatesWhere(_pb.filter('unitType = {:id}', {'id': unitTypeId}));
    await _pb.collection('unit_types').delete(unitTypeId);
  }

  /// Deletes a unit only if NO reservation references it (any status).
  static Future<void> deleteUnit(String unitId) async {
    final reservations = await countReservationsForUnit(unitId);
    if (reservations > 0) {
      throw ConfigInUseException(
        'This unit has $reservations reservation'
        '${reservations == 1 ? '' : 's'} and cannot be deleted. '
        'Deactivate it instead.',
      );
    }
    await _pb.collection('units').delete(unitId);
  }

  /// Deletes a stay type only if NO reservation references it.
  /// Its rates are removed explicitly first.
  static Future<void> deleteStayType(String stayTypeId) async {
    final reservations = await countReservationsForStayType(stayTypeId);
    if (reservations > 0) {
      throw ConfigInUseException(
        'This stay type is used by $reservations reservation'
        '${reservations == 1 ? '' : 's'} and cannot be deleted. '
        'Deactivate it instead.',
      );
    }
    await _deleteRatesWhere(_pb.filter('stayType = {:id}', {'id': stayTypeId}));
    await _pb.collection('stay_types').delete(stayTypeId);
  }

  /// A readable message for errors from PocketBase.
  static String friendlyError(Object error) {
    if (error is ConfigInUseException) return error.message;
    if (error is ClientException) {
      if (error.statusCode == 0) {
        return 'Cannot reach PocketBase. Make sure the server is running.';
      }
      final data = error.response['data'];
      if (data is Map && data.isNotEmpty) {
        final messages = <String>[];
        data.forEach((field, value) {
          if (value is Map) {
            final code = '${value['code'] ?? ''}';
            if (code == 'validation_not_unique') {
              messages.add('That $field is already in use.');
            } else {
              messages.add('$field: ${value['message'] ?? 'invalid value'}');
            }
          }
        });
        if (messages.isNotEmpty) return messages.join(' ');
      }
      final message = error.response['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    // Unexpected error: keep the details in the debug console only.
    if (kDebugMode) debugPrint('Unexpected error: $error');
    return 'Something went wrong. Please try again.';
  }
}
