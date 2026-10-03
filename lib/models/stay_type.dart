import 'package:pocketbase/pocketbase.dart';

/// How a stay type is priced.
enum PricingBasis {
  perNight('per_night'),
  perStay('per_stay');

  final String value;
  const PricingBasis(this.value);

  static PricingBasis fromValue(String value) => PricingBasis.values.firstWhere(
    (b) => b.value == value,
    orElse: () => PricingBasis.perStay,
  );
}

/// A configurable stay type (Overnight, Day Tour, Night Tour, ...).
/// PocketBase collection: `stay_types`.
class StayType {
  final String id;
  final String name;
  final String description;

  /// 24-hour "HH:mm" strings, e.g. "14:00".
  final String checkInTime;
  final String checkOutTime;

  /// True when check-out happens on the day after check-in (crosses midnight).
  final bool endsNextDay;
  final bool allowMultipleNights;
  final PricingBasis pricingBasis;
  final bool isActive;
  final int sortOrder;

  const StayType({
    required this.id,
    required this.name,
    this.description = '',
    required this.checkInTime,
    required this.checkOutTime,
    this.endsNextDay = false,
    this.allowMultipleNights = false,
    this.pricingBasis = PricingBasis.perStay,
    this.isActive = true,
    this.sortOrder = 0,
  });

  /// Name used for reservations that have no stay type (legacy records).
  static const String legacyFallbackName = 'Overnight';

  factory StayType.fromRecord(RecordModel record) {
    return StayType(
      id: record.id,
      name: record.getStringValue('name'),
      description: record.getStringValue('description'),
      checkInTime: record.getStringValue('checkInTime'),
      checkOutTime: record.getStringValue('checkOutTime'),
      endsNextDay: record.getBoolValue('endsNextDay'),
      allowMultipleNights: record.getBoolValue('allowMultipleNights'),
      pricingBasis: PricingBasis.fromValue(
        record.getStringValue('pricingBasis'),
      ),
      isActive: record.getBoolValue('isActive'),
      sortOrder: record.getIntValue('sortOrder'),
    );
  }

  /// Hour/minute of check-in, parsed from [checkInTime] (defaults to 00:00).
  ({int hour, int minute}) get checkIn => _parseTime(checkInTime);

  /// Hour/minute of check-out, parsed from [checkOutTime] (defaults to 00:00).
  ({int hour, int minute}) get checkOut => _parseTime(checkOutTime);

  static ({int hour, int minute}) _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return (hour: 0, minute: 0);
    return (
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  /// Body for create/update requests.
  Map<String, dynamic> toBody() => {
    'name': name,
    'description': description,
    'checkInTime': checkInTime,
    'checkOutTime': checkOutTime,
    'endsNextDay': endsNextDay,
    'allowMultipleNights': allowMultipleNights,
    'pricingBasis': pricingBasis.value,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };
}
