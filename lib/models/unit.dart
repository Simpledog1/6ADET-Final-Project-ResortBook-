import 'package:pocketbase/pocketbase.dart';
import 'unit_type.dart';

/// A bookable unit (a room, cottage, villa, pavilion, ...).
/// PocketBase collection: `units` (formerly `rooms`).
class Unit {
  final String id;
  final String name;
  final String unitTypeId;

  /// The linked unit type, when the record was fetched with `expand=unitType`.
  final UnitType? unitType;
  final int capacity;
  final bool isActive;
  final int sortOrder;
  final String cleaningStatus;

  /// Legacy free-text type carried over from `rooms`.
  final String legacyType;

  const Unit({
    required this.id,
    required this.name,
    this.unitTypeId = '',
    this.unitType,
    this.capacity = 0,
    this.isActive = true,
    this.sortOrder = 0,
    this.cleaningStatus = '',
    this.legacyType = '',
  });

  factory Unit.fromRecord(RecordModel record) {
    // Expanded relation (present only when fetched with expand=unitType).
    final typeRecords = record.get<List<RecordModel>>('expand.unitType');
    return Unit(
      id: record.id,
      name: record.getStringValue('name'),
      unitTypeId: record.getStringValue('unitType'),
      unitType: typeRecords.isNotEmpty
          ? UnitType.fromRecord(typeRecords.first)
          : null,
      capacity: record.getIntValue('capacity'),
      isActive: record.getBoolValue('isActive'),
      sortOrder: record.getIntValue('sortOrder'),
      cleaningStatus: record.getStringValue('cleaningStatus'),
      legacyType: record.getStringValue('type'),
    );
  }

  /// Unit type name, falling back to the legacy text type.
  String get typeName => unitType?.name ?? legacyType;

  /// "Cottage 3 · Family Cottage" (or just the name if there is no type).
  String get displayLabel => typeName.isEmpty ? name : '$name · $typeName';

  /// Body for create/update requests.
  Map<String, dynamic> toBody() => {
    'name': name,
    'unitType': unitTypeId.isEmpty ? null : unitTypeId,
    'capacity': capacity,
    'isActive': isActive,
    'sortOrder': sortOrder,
    'cleaningStatus': cleaningStatus,
  };
}
