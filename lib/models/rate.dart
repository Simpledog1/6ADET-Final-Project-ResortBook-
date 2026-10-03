import 'package:pocketbase/pocketbase.dart';

/// Price (in Philippine pesos) for one unit type + stay type combination.
/// PocketBase collection: `rates`.
class Rate {
  final String id;
  final String unitTypeId;
  final String stayTypeId;
  final double price;

  const Rate({
    required this.id,
    required this.unitTypeId,
    required this.stayTypeId,
    required this.price,
  });

  factory Rate.fromRecord(RecordModel record) {
    return Rate(
      id: record.id,
      unitTypeId: record.getStringValue('unitType'),
      stayTypeId: record.getStringValue('stayType'),
      price: record.getDoubleValue('price'),
    );
  }

  /// Body for create/update requests.
  Map<String, dynamic> toBody() => {
        'unitType': unitTypeId,
        'stayType': stayTypeId,
        'price': price,
      };
}
