// A small configurable stand-in for PocketBase used by the widget tests.
// It records the calls the screens make instead of talking to a server.

import 'package:pocketbase/pocketbase.dart';

import 'package:final_project/logic/config_rules.dart';
import 'package:final_project/models/rate.dart';
import 'package:final_project/models/reservation.dart';
import 'package:final_project/models/stay_type.dart';
import 'package:final_project/models/unit.dart';
import 'package:final_project/models/unit_type.dart';
import 'package:final_project/services/config_service.dart';
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

  /// New reservations saved through Add Reservation.
  final created = <Reservation>[];
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
  Future<Reservation> createReservation({
    required String guestName,
    String phone = '',
    String email = '',
    int guestCount = 0,
    required Unit unit,
    StayType? stayType,
    required DateTime startAt,
    required DateTime endAt,
    String status = 'Reserved',
    String notes = '',
    double rate = 0,
    PricingBasis? rateBasis,
    int quantity = 0,
    double totalAmount = 0,
  }) async {
    calls.add('create');
    final reservation = Reservation(
      id: 'new${created.length + 1}',
      guestName: guestName,
      phone: phone,
      email: email,
      guestCount: guestCount,
      unitId: unit.id,
      stayTypeId: stayType?.id ?? '',
      startAt: startAt,
      endAt: endAt,
      status: status,
      notes: notes,
      unitName: unit.name,
      unitTypeName: unit.typeName,
      stayTypeName: stayType?.name ?? '',
      rate: rate,
      rateBasis: rateBasis?.value ?? '',
      quantity: quantity,
      totalAmount: totalAmount,
    );
    created.add(reservation);
    return reservation;
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

  @override
  Future<UnitType> createUnitType(UnitType type) async {
    calls.add('createUnitType');
    final saved = UnitType(
      id: 'ut_new${unitTypes.length + 1}',
      name: type.name,
      description: type.description,
      defaultCapacity: type.defaultCapacity,
      isActive: type.isActive,
      sortOrder: type.sortOrder,
    );
    unitTypes = [...unitTypes, saved];
    return saved;
  }

  @override
  Future<UnitType> updateUnitType(UnitType type) async {
    calls.add('updateUnitType');
    unitTypes = [for (final t in unitTypes) t.id == type.id ? type : t];
    return type;
  }

  @override
  Future<Unit> updateUnit(Unit unit) async {
    calls.add('updateUnit');
    units = [for (final u in units) u.id == unit.id ? unit : u];
    return unit;
  }

  @override
  Future<void> setUnitTypeActive(String id, bool isActive) async {
    calls.add('setUnitTypeActive');
    unitTypes = [
      for (final t in unitTypes)
        t.id == id
            ? UnitType(
                id: t.id,
                name: t.name,
                description: t.description,
                defaultCapacity: t.defaultCapacity,
                isActive: isActive,
                sortOrder: t.sortOrder,
              )
            : t,
    ];
  }

  @override
  Future<void> deactivateUnitType(
    String unitTypeId, {
    List<String> alsoDeactivateUnitIds = const [],
  }) async {
    await setUnitTypeActive(unitTypeId, false);
    for (final id in alsoDeactivateUnitIds) {
      await setUnitActive(id, false);
    }
  }

  @override
  Future<void> setUnitActive(String id, bool isActive) async {
    calls.add('setUnitActive');
    units = [
      for (final u in units)
        u.id == id
            ? Unit(
                id: u.id,
                name: u.name,
                unitTypeId: u.unitTypeId,
                unitType: u.unitType,
                capacity: u.capacity,
                isActive: isActive,
                sortOrder: u.sortOrder,
              )
            : u,
    ];
  }

  /// Same rule as ConfigService.deleteUnitType: refused while any unit
  /// (active or inactive) uses the type; its rates go with it.
  @override
  Future<void> deleteUnitType(String unitTypeId) async {
    calls.add('deleteUnitType');
    final count = units.where((u) => u.unitTypeId == unitTypeId).length;
    if (!ConfigRules.canDeleteUnitType(count)) {
      throw ConfigInUseException(ConfigRules.unitTypeInUseMessage(count));
    }
    rates = rates.where((r) => r.unitTypeId != unitTypeId).toList();
    unitTypes = unitTypes.where((t) => t.id != unitTypeId).toList();
  }

  /// Same rule as ConfigService.deleteUnit: refused while any reservation
  /// (any status) uses the unit.
  @override
  Future<void> deleteUnit(String unitId) async {
    calls.add('deleteUnit');
    final count = reservations.where((r) => r.unitId == unitId).length;
    if (!ConfigRules.canDeleteUnit(count)) {
      throw ConfigInUseException(ConfigRules.unitInUseMessage(count));
    }
    units = units.where((u) => u.id != unitId).toList();
  }

  @override
  Future<ReservationUsage> getReservationUsage() async {
    if (failLoads) throw _offline;
    final byUnit = <String, int>{};
    final byStayType = <String, int>{};
    for (final r in reservations) {
      byUnit[r.unitId] = (byUnit[r.unitId] ?? 0) + 1;
      if (r.stayTypeId.isNotEmpty) {
        byStayType[r.stayTypeId] = (byStayType[r.stayTypeId] ?? 0) + 1;
      }
    }
    return ReservationUsage(
      totalByUnit: byUnit,
      upcomingByUnit: const {},
      maxUpcomingGuestsByUnit: const {},
      totalByStayType: byStayType,
    );
  }

  @override
  Future<Unit> createUnit(Unit unit) async {
    calls.add('createUnit');
    final saved = Unit(
      id: 'unit_new${units.length + 1}',
      name: unit.name,
      unitTypeId: unit.unitTypeId,
      unitType: unitTypes.where((t) => t.id == unit.unitTypeId).firstOrNull,
      capacity: unit.capacity,
      isActive: unit.isActive,
    );
    units = [...units, saved];
    return saved;
  }

  @override
  Future<Rate> saveRate({
    required String unitTypeId,
    required String stayTypeId,
    required double price,
  }) async {
    calls.add('saveRate');
    final saved = Rate(
      id: 'rate_new${rates.length + 1}',
      unitTypeId: unitTypeId,
      stayTypeId: stayTypeId,
      price: price,
    );
    rates = [...rates, saved];
    return saved;
  }
}
