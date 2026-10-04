import '../logic/reservation_workflow.dart';
import '../models/rate.dart';
import '../models/reservation.dart';
import '../models/stay_type.dart';
import '../models/unit.dart';
import '../models/unit_type.dart';
import 'config_service.dart';
import 'pocketbase_service.dart';

/// The PocketBase calls used by the reservation screens (Dashboard,
/// Reservation List, Calendar, Details and Add / Edit Reservation) and by
/// the Unit Type / Unit forms of Manage Resort.
///
/// It only forwards to the existing [PocketBaseService] / [ConfigService]
/// methods. Screens take one as an optional parameter so widget tests can
/// pass a small fake instead of needing a running PocketBase server; the
/// app itself always uses this default.
class ReservationGateway {
  const ReservationGateway();

  /// All reservations, newest stay first ([searchQuery] filters by guest).
  Future<List<Reservation>> getReservations({String searchQuery = ''}) =>
      PocketBaseService.getReservations(searchQuery: searchQuery);

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

  /// Saves a new reservation (see [PocketBaseService.createReservation]).
  Future<Reservation> createReservation({
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
  }) => PocketBaseService.createReservation(
    guestName: guestName,
    phone: phone,
    email: email,
    guestCount: guestCount,
    unit: unit,
    stayType: stayType,
    startAt: startAt,
    endAt: endAt,
    status: status,
    notes: notes,
    rate: rate,
    rateBasis: rateBasis,
    quantity: quantity,
    totalAmount: totalAmount,
  );

  Future<List<UnitType>> getUnitTypes({bool activeOnly = false}) =>
      ConfigService.getUnitTypes(activeOnly: activeOnly);

  Future<List<StayType>> getStayTypes({bool activeOnly = false}) =>
      ConfigService.getStayTypes(activeOnly: activeOnly);

  Future<List<Unit>> getUnits({bool activeOnly = false}) =>
      ConfigService.getUnits(activeOnly: activeOnly);

  Future<List<Rate>> getRates() => ConfigService.getRates();

  // Unit types and units: used by the Manage Resort forms and by
  // "Add new unit" in Add Reservation (one shared set of records).

  Future<UnitType> createUnitType(UnitType type) =>
      ConfigService.createUnitType(type);

  Future<UnitType> updateUnitType(UnitType type) =>
      ConfigService.updateUnitType(type);

  Future<Unit> createUnit(Unit unit) => ConfigService.createUnit(unit);

  Future<Unit> updateUnit(Unit unit) => ConfigService.updateUnit(unit);

  Future<void> setUnitTypeActive(String id, bool isActive) =>
      ConfigService.setUnitTypeActive(id, isActive);

  /// Deactivates a unit type and, only when asked, the listed units.
  Future<void> deactivateUnitType(
    String unitTypeId, {
    List<String> alsoDeactivateUnitIds = const [],
  }) => ConfigService.deactivateUnitType(
    unitTypeId,
    alsoDeactivateUnitIds: alsoDeactivateUnitIds,
  );

  Future<void> setUnitActive(String id, bool isActive) =>
      ConfigService.setUnitActive(id, isActive);

  /// Deletes a unit type only if no unit uses it (checked again first);
  /// otherwise throws [ConfigInUseException].
  Future<void> deleteUnitType(String unitTypeId) =>
      ConfigService.deleteUnitType(unitTypeId);

  /// Deletes a unit only if it has no reservations (checked again first);
  /// otherwise throws [ConfigInUseException].
  Future<void> deleteUnit(String unitId) => ConfigService.deleteUnit(unitId);

  /// Reservation counts per unit / stay type (for delete checks).
  Future<ReservationUsage> getReservationUsage() =>
      ConfigService.getReservationUsage();

  /// Creates or updates the rate for a unit type + stay type.
  Future<Rate> saveRate({
    required String unitTypeId,
    required String stayTypeId,
    required double price,
  }) => ConfigService.saveRate(
    unitTypeId: unitTypeId,
    stayTypeId: stayTypeId,
    price: price,
  );
}
