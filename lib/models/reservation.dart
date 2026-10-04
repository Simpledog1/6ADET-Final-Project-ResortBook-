import 'package:pocketbase/pocketbase.dart';
import 'stay_type.dart';
import 'unit.dart';

/// A guest's booking of one unit for one stay.
/// PocketBase collection: `reservations`.
///
/// Guest details (name, phone, email, guest count) live directly on the
/// reservation. Names and prices of the unit / stay type are also saved as
/// snapshots so editing the resort configuration later doesn't change
/// historical reservations.
class Reservation {
  final String id;
  final String guestName;
  final String phone;
  final String email;
  final int guestCount;

  /// Relation id of the booked unit (`unit` field).
  final String unitId;

  /// The linked unit, when fetched with `expand=unit` (or `unit.unitType`).
  final Unit? unit;

  /// Relation id of the stay type. Empty for legacy reservations.
  final String stayTypeId;

  /// The linked stay type, when fetched with `expand=stayType`.
  final StayType? stayType;

  /// Precise start/end of the stay, in local time.
  /// Stored in PocketBase as UTC (`startAt` / `endAt`, formerly
  /// `checkInDate` / `checkOutDate`).
  final DateTime startAt;
  final DateTime endAt;

  final String status;
  final String notes;

  // Snapshots taken when the reservation was created.
  final String unitName;
  final String unitTypeName;
  final String stayTypeName;
  final double rate; // 0 when not set (PocketBase numbers default to 0)
  final String rateBasis; // 'per_night' | 'per_stay' | ''
  final int quantity; // nights (per_night) or 1 (per_stay)
  final double totalAmount; // 0 when not set

  /// When the record was created (PocketBase `created` field), local time.
  /// Null when the collection has no such field or it is empty.
  final DateTime? createdAt;

  Reservation({
    required this.id,
    required this.guestName,
    required this.phone,
    required this.email,
    this.guestCount = 0,
    required this.unitId,
    this.unit,
    this.stayTypeId = '',
    this.stayType,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.notes = '',
    this.unitName = '',
    this.unitTypeName = '',
    this.stayTypeName = '',
    this.rate = 0,
    this.rateBasis = '',
    this.quantity = 0,
    this.totalAmount = 0,
    this.createdAt,
  });

  factory Reservation.fromRecord(RecordModel record) {
    final unitRecords = record.get<List<RecordModel>>('expand.unit');
    final stayRecords = record.get<List<RecordModel>>('expand.stayType');

    return Reservation(
      id: record.id,
      guestName: record.getStringValue('guestName'),
      phone: record.getStringValue('phone'),
      email: record.getStringValue('email'),
      guestCount: record.getIntValue('guestCount'),
      unitId: record.getStringValue('unit'),
      unit: unitRecords.isNotEmpty ? Unit.fromRecord(unitRecords.first) : null,
      stayTypeId: record.getStringValue('stayType'),
      stayType: stayRecords.isNotEmpty
          ? StayType.fromRecord(stayRecords.first)
          : null,
      startAt: _parseDate(record.getStringValue('startAt')),
      endAt: _parseDate(record.getStringValue('endAt')),
      status: record.getStringValue('status'),
      notes: record.getStringValue('notes'),
      unitName: record.getStringValue('unitName'),
      unitTypeName: record.getStringValue('unitTypeName'),
      stayTypeName: record.getStringValue('stayTypeName'),
      rate: record.getDoubleValue('rate'),
      rateBasis: record.getStringValue('rateBasis'),
      quantity: record.getIntValue('quantity'),
      totalAmount: record.getDoubleValue('totalAmount'),
      createdAt: _parseOptionalDate(record.getStringValue('created')),
    );
  }

  /// PocketBase returns dates like "2026-06-15 06:00:00.000Z" (UTC).
  /// Converted to local time for display and comparisons.
  static DateTime _parseDate(String value) {
    final parsed = DateTime.tryParse(value);
    return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
  }

  static DateTime? _parseOptionalDate(String value) {
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  // ── Display helpers (snapshot first, then live relation) ──────────────

  String get unitDisplayName =>
      unitName.isNotEmpty ? unitName : (unit?.name ?? '');

  String get unitTypeDisplayName =>
      unitTypeName.isNotEmpty ? unitTypeName : (unit?.typeName ?? '');

  /// Reservations without a stay type are legacy bookings → "Overnight".
  String get stayTypeDisplayName {
    if (stayTypeName.isNotEmpty) return stayTypeName;
    if (stayType != null) return stayType!.name;
    return StayType.legacyFallbackName;
  }

  bool get isLegacy => stayTypeId.isEmpty;

  bool get isCancelled => status.toLowerCase().contains('cancel');
}
