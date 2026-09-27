import 'package:pocketbase/pocketbase.dart';

class Reservation {
  final String id;
  final String guestName;
  final String phone;
  final String email;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final String assignedRoomId;
  final String status;

  Reservation({
    required this.id,
    required this.guestName,
    required this.phone,
    required this.email,
    required this.checkInDate,
    required this.checkOutDate,
    required this.assignedRoomId,
    required this.status,
  });

  factory Reservation.fromRecord(RecordModel record) {
    return Reservation(
      id: record.id,
      guestName: record.getStringValue('guestName'),
      phone: record.getStringValue('phone'),
      email: record.getStringValue('email'),
      // Convert the string timestamps from the database back into Dart DateTimes
      checkInDate: DateTime.parse(record.getStringValue('checkInDate')),
      checkOutDate: DateTime.parse(record.getStringValue('checkOutDate')),
      assignedRoomId: record.getStringValue('assignedRoomId'),
      status: record.getStringValue('status'),
    );
  }
}
