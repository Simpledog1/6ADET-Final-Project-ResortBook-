import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/foundation.dart';
import '../models/reservation.dart';

class PocketBaseService {
  // 127.0.0.1 is the local loopback address for Windows desktop testing.
  static final pb = PocketBase('http://127.0.0.1:8090');

  static Future<List<Reservation>> getReservations({
    String searchQuery = '',
  }) async {
    try {
      String filterString = '';
      if (searchQuery.isNotEmpty) {
        filterString = 'guestName ~ "$searchQuery"';
      }

      final result = await pb
          .collection('reservations')
          .getList(
            sort: '-checkInDate', // Updated to match your model property
            filter: filterString,
            expand: 'assignedRoomId',
          );

      return result.items
          .map((record) => Reservation.fromRecord(record))
          .toList();
    } catch (e) {
      debugPrint('Error fetching reservations: $e');
      rethrow;
    }
  }
}
