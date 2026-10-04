import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/foundation.dart';
import '../logic/reservation_workflow.dart';
import '../models/reservation.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';

class PocketBaseService {
  // 127.0.0.1 is the local loopback address for Windows desktop testing.
  static final pb = PocketBase('http://127.0.0.1:8090');

  /// Relations loaded with every reservation (unit + its type, stay type).
  static const String reservationExpand = 'unit,unit.unitType,stayType';

  /// All reservations, newest stay first.
  ///
  /// Loads every page (no 30-record limit). The search text is passed as a
  /// filter parameter, so quotes in a name can't break the query.
  static Future<List<Reservation>> getReservations({
    String searchQuery = '',
  }) async {
    try {
      final filterString = searchQuery.isEmpty
          ? null
          : pb.filter('guestName ~ {:q}', {'q': searchQuery});

      final records = await pb
          .collection('reservations')
          .getFullList(
            sort: '-startAt',
            filter: filterString,
            expand: reservationExpand,
          );

      return records.map((record) => Reservation.fromRecord(record)).toList();
    } catch (e) {
      debugPrint('Error fetching reservations: $e');
      rethrow;
    }
  }

  /// One reservation by id, with its unit (+ unit type) and stay type.
  static Future<Reservation> getReservation(String id) async {
    final record = await pb
        .collection('reservations')
        .getOne(id, expand: reservationExpand);
    return Reservation.fromRecord(record);
  }

  /// Updates the given fields of a reservation and returns the saved record.
  ///
  /// The body is built by `ReservationWorkflow.buildUpdateBody` (edits) or
  /// [updateReservationStatus]; only the fields it contains are changed.
  static Future<Reservation> updateReservation(
    String id,
    Map<String, dynamic> body,
  ) async {
    final record = await pb
        .collection('reservations')
        .update(id, body: body, expand: reservationExpand);
    return Reservation.fromRecord(record);
  }

  /// Changes only the `status` field (Check In, Complete, Cancel, Restore).
  static Future<Reservation> updateReservationStatus(String id, String status) {
    return updateReservation(id, {'status': status});
  }

  /// Every reservation for one unit (any status).
  static Future<List<Reservation>> getReservationsForUnit(String unitId) async {
    final records = await pb
        .collection('reservations')
        .getFullList(filter: pb.filter('unit = {:unit}', {'unit': unitId}));
    return records.map((record) => Reservation.fromRecord(record)).toList();
  }

  /// Non-cancelled reservations of [unitId] whose time range overlaps
  /// [start]–[end], using `start < existingEnd && end > existingStart`.
  /// A booking ending exactly when another begins is not returned.
  static Future<List<Reservation>> findOverlappingReservations({
    required String unitId,
    required DateTime start,
    required DateTime end,
    String? excludeReservationId,
  }) async {
    var filter = pb.filter(
      'unit = {:unit} && startAt < {:end} && endAt > {:start} && status !~ "cancel"',
      {'unit': unitId, 'start': start, 'end': end},
    );
    if (excludeReservationId != null && excludeReservationId.isNotEmpty) {
      filter += pb.filter(' && id != {:id}', {'id': excludeReservationId});
    }

    final records = await pb
        .collection('reservations')
        .getFullList(filter: filter, expand: reservationExpand);
    return records.map((record) => Reservation.fromRecord(record)).toList();
  }

  /// Creates a reservation.
  ///
  /// Dates are stored in UTC. Unit / stay type names and the price are saved
  /// as snapshots so later configuration changes don't alter this booking.
  static Future<Reservation> createReservation({
    required String guestName,
    String phone = '',
    String email = '',
    int guestCount = 0,
    required Unit unit,
    StayType? stayType,
    required DateTime startAt,
    required DateTime endAt,
    String status = ReservationStatus.reserved,
    String notes = '',
    double rate = 0,
    PricingBasis? rateBasis,
    int quantity = 0,
    double totalAmount = 0,
  }) async {
    final body = <String, dynamic>{
      'guestName': guestName,
      'phone': phone,
      'email': email,
      'guestCount': guestCount,
      'unit': unit.id,
      'stayType': stayType?.id,
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
      'status': status,
      'notes': notes,
      'unitName': unit.name,
      'unitTypeName': unit.typeName,
      'stayTypeName': stayType?.name ?? '',
      'rate': rate,
      'rateBasis': rateBasis?.value ?? '',
      'quantity': quantity,
      'totalAmount': totalAmount,
    };

    final record = await pb
        .collection('reservations')
        .create(body: body, expand: reservationExpand);
    return Reservation.fromRecord(record);
  }
}
