import '../models/rate.dart';
import '../models/reservation.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';
import 'config_service.dart';
import 'pocketbase_service.dart';

/// The PocketBase calls used by Reservation Details and Edit Reservation.
///
/// It only forwards to the existing [PocketBaseService] / [ConfigService]
/// methods. Screens take one as an optional parameter so widget tests can
/// pass a small fake instead of needing a running PocketBase server; the
/// app itself always uses this default.
class ReservationGateway {
  const ReservationGateway();

  Future<Reservation> getReservation(String id) =>
      PocketBaseService.getReservation(id);

  Future<Reservation> updateReservation(String id, Map<String, dynamic> body) =>
      PocketBaseService.updateReservation(id, body);

  Future<Reservation> updateStatus(String id, String status) =>
      PocketBaseService.updateReservationStatus(id, status);

  /// Non-cancelled reservations of [unitId] overlapping [start]–[end],
  /// ignoring [excludeReservationId].
  Future<List<Reservation>> findOverlapping({
    required String unitId,
    required DateTime start,
    required DateTime end,
    String? excludeReservationId,
  }) => PocketBaseService.findOverlappingReservations(
    unitId: unitId,
    start: start,
    end: end,
    excludeReservationId: excludeReservationId,
  );

  Future<List<StayType>> getStayTypes({bool activeOnly = false}) =>
      ConfigService.getStayTypes(activeOnly: activeOnly);

  Future<List<Unit>> getUnits({bool activeOnly = false}) =>
      ConfigService.getUnits(activeOnly: activeOnly);

  Future<List<Rate>> getRates() => ConfigService.getRates();
}
