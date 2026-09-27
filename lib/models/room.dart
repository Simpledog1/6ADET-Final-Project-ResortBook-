import 'package:pocketbase/pocketbase.dart';

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
    return Room(
      id: record.id,
      roomNumber: record.getStringValue('roomNumber'),
      type: record.getStringValue('type'),
      maxCapacity: record.getIntValue('maxCapacity'),
      pricePerNight: record.getDoubleValue('pricePerNight'),
      cleaningStatus: record.getStringValue('cleaningStatus'),
    );
  }
}
