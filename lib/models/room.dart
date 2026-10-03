import 'package:pocketbase/pocketbase.dart';

/// LEGACY MODEL — kept temporarily for compatibility during the
/// Room → Unit migration. New code should use `Unit` (models/unit.dart).
/// Remove this file once the whole migration is complete and confirmed.
///
/// Reads both the new `units` field names and the old `rooms` names.
class Room {
  final String id;
  final String roomNumber;
  final String type;
  final int maxCapacity;
  final double pricePerNight;
  final String cleaningStatus;

  Room({
    required this.id,
    required this.roomNumber,
    required this.type,
    required this.maxCapacity,
    required this.pricePerNight,
    required this.cleaningStatus,
  });

  factory Room.fromRecord(RecordModel record) {
    String firstNonEmpty(List<String> keys) {
      for (final key in keys) {
        final value = record.getStringValue(key);
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final capacity = record.getIntValue('capacity');

    return Room(
      id: record.id,
      roomNumber: firstNonEmpty(['name', 'roomNumber']),
      type: firstNonEmpty(['expand.unitType.name', 'type']),
      maxCapacity: capacity != 0 ? capacity : record.getIntValue('maxCapacity'),
      pricePerNight: record.getDoubleValue('pricePerNight'),
      cleaningStatus: record.getStringValue('cleaningStatus'),
    );
  }
}
