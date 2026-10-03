import 'package:pocketbase/pocketbase.dart';

/// A configurable kind of unit (Room, Cottage, Villa, Function Hall, ...).
/// PocketBase collection: `unit_types`.
class UnitType {
  final String id;
  final String name;
  final String description;
  final int defaultCapacity;
  final bool isActive;
  final int sortOrder;

  const UnitType({
    required this.id,
    required this.name,
    this.description = '',
    this.defaultCapacity = 0,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory UnitType.fromRecord(RecordModel record) {
    return UnitType(
      id: record.id,
      name: record.getStringValue('name'),
      description: record.getStringValue('description'),
      defaultCapacity: record.getIntValue('defaultCapacity'),
      isActive: record.getBoolValue('isActive'),
      sortOrder: record.getIntValue('sortOrder'),
    );
  }

  /// Body for create/update requests.
  Map<String, dynamic> toBody() => {
    'name': name,
    'description': description,
    'defaultCapacity': defaultCapacity,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };
}
