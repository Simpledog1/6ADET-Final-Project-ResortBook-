// A small configurable stand-in for PocketBase used by the widget tests.
// It records the calls the screens make instead of talking to a server.

import 'package:pocketbase/pocketbase.dart';

import 'package:final_project/models/rate.dart';
import 'package:final_project/models/reservation.dart';
import 'package:final_project/models/stay_type.dart';
import 'package:final_project/models/unit.dart';
import 'package:final_project/models/unit_type.dart';
import 'package:final_project/services/reservation_gateway.dart';

// ── Sample configuration ────────────────────────────────────────────────

const overnight = StayType(
  id: 'st_overnight',
  name: 'Overnight',
  checkInTime: '14:00',
  checkOutTime: '12:00',
  endsNextDay: true,
  allowMultipleNights: true,
  pricingBasis: PricingBasis.perNight,
);
const dayTour = StayType(
  id: 'st_day',
  name: 'Day Tour',
  checkInTime: '08:00',
  checkOutTime: '17:00',
);
const nightTour = StayType(
  id: 'st_night',
  name: 'Night Tour',
  checkInTime: '19:00',
  checkOutTime: '06:00',
  endsNextDay: true,
);

const cottageType = UnitType(id: 'ut_cottage', name: 'Cottage');

const cottageA = Unit(
  id: 'unit_a',
  name: 'Cottage A',
  unitTypeId: 'ut_cottage',
  capacity: 4,
);
const cottageB = Unit(
  id: 'unit_b',
  name: 'Cottage B',
  unitTypeId: 'ut_cottage',
  capacity: 6,
);

const cottageOvernightRate = Rate(
  id: 'rate_overnight',
  unitTypeId: 'ut_cottage',
  stayTypeId: 'st_overnight',
  price: 2500,
);
const cottageDayRate = Rate(
  id: 'rate_day',
  unitTypeId: 'ut_cottage',
  stayTypeId: 'st_day',
  price: 800,
);
const cottageNightRate = Rate(
  id: 'rate_night',
  unitTypeId: 'ut_cottage',
  stayTypeId: 'st_night',
  price: 1200,
);

/// A reservation with sensible defaults (Overnight on Cottage A).
Reservation makeReservation({
  String id = 'r1',
  String guestName = 'Maria Santos',
  String phone = '0917 000 0000',
  String email = 'maria@example.com',
  int guestCount = 2,
  String unitId = 'unit_a',
  String unitName = 'Cottage A',
  String stayTypeId = 'st_overnight',
  String stayTypeName = 'Overnight',
  required DateTime start,
  required DateTime end,
  String status = 'Reserved',
  String notes = '',
  double rate = 2500,
  String rateBasis = 'per_night',
  int quantity = 1,
  double totalAmount = 2500,
  DateTime? createdAt,
}) {
  return Reservation(
    id: id,
    guestName: guestName,
    phone: phone,
    email: email,
    guestCount: guestCount,
    unitId: unitId,
    stayTypeId: stayTypeId,
    startAt: start,
    endAt: end,
    status: status,
    notes: notes,
    unitName: unitName,
    unitTypeName: 'Cottage',
    stayTypeName: stayTypeName,
    rate: rate,
    rateBasis: rateBasis,
    quantity: quantity,
    totalAmount: totalAmount,
    createdAt: createdAt,
  );
}

// ── Fake gateway ────────────────────────────────────────────────────────

class FakeGateway extends ReservationGateway {
  FakeGateway({
    List<Reservation>? reservations,
    this.current,
    List<Reservation>? overlapping,
    List<UnitType>? unitTypes,
    List<Unit>? units,
    List<StayType>? stayTypes,
    List<Rate>? rates,
  }) : reservations = reservations ?? [],
       overlapping = overlapping ?? [],
       unitTypes = unitTypes ?? [cottageType],
       units = units ?? [cottageA, cottageB],
       stayTypes = stayTypes ?? [overnight, dayTour, nightTour],
       rates =
           rates ?? [cottageOvernightRate, cottageDayRate, cottageNightRate];

  List<Reservation> reservations;
  Reservation? current;
  List<Reservation> overlapping;
  List<UnitType> unitTypes;
  List<Unit> units;
  List<StayType> stayTypes;
  List<Rate> rates;

  /// When true, loading reservations / configuration fails like an
  /// unreachable server.
  bool failLoads = false;

  /// Calls in order, e.g. ['overlap', 'update'].
  final calls = <String>[];
  final updates = <Map<String, dynamic>>[];
  int reservationLoads = 0;

  ClientException get _offline => ClientException(statusCode: 0);

  @override
  Future<List<Reservation>> getReservations({String searchQuery = ''}) async {
    reservationLoads++;
    if (failLoads) throw _offline;
    final q = searchQuery.toLowerCase();
    return reservations
        .where((r) => r.guestName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<Reservation> getReservation(String id) async =>
      current ?? reservations.firstWhere((r) => r.id == id);

  @override
  Future<Reservation> updateReservation(
    String id,
    Map<String, dynamic> body,
  ) async {
    calls.add('update');
    updates.add(body);
    return current ?? reservations.firstWhere((r) => r.id == id);
  }

  @override
  Future<Reservation> updateStatus(String id, String status) async {
    calls.add('status:$status');
    return current ?? reservations.firstWhere((r) => r.id == id);
  }

  @override
  Future<List<Reservation>> findOverlapping({
    required String unitId,
    required DateTime start,
    required DateTime end,
    String? excludeReservationId,
  }) async {
    calls.add('overlap');
    return overlapping;
  }

  @override
  Future<List<UnitType>> getUnitTypes({bool activeOnly = false}) async {
    if (failLoads) throw _offline;
    return unitTypes;
  }

  @override
  Future<List<Unit>> getUnits({bool activeOnly = false}) async {
    if (failLoads) throw _offline;
    return activeOnly ? units.where((u) => u.isActive).toList() : units;
  }

  @override
  Future<List<StayType>> getStayTypes({bool activeOnly = false}) async {
    if (failLoads) throw _offline;
    return activeOnly ? stayTypes.where((s) => s.isActive).toList() : stayTypes;
  }

  @override
  Future<List<Rate>> getRates() async {
    if (failLoads) throw _offline;
    return rates;
  }
}
