// Checks that the field names the Flutter code reads and writes exist in the
// PocketBase schema file (pocketbase/pb_schema.json), with a compatible type.
//
// Why: the models read values with record.getStringValue('name') and friends,
// which quietly return an empty value when the name is wrong, so a typo would
// show up as blank data, not as an error.
//
// Limits: this compares the code with pb_schema.json, not with a running
// PocketBase. To compare with the real server, follow the steps in
// docs/09-reservations-and-data-integrity.md ("Checking the models against
// PocketBase").

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// model file -> PocketBase collection it is read from.
const _modelCollections = {
  'lib/models/reservation.dart': 'reservations',
  'lib/models/unit.dart': 'units',
  'lib/models/unit_type.dart': 'unit_types',
  'lib/models/stay_type.dart': 'stay_types',
  'lib/models/rate.dart': 'rates',
};

/// record.getXValue('field') -> schema field types it can safely read.
const _readers = {
  'getStringValue': {'text', 'email', 'select', 'relation', 'date', 'autodate'},
  'getIntValue': {'number'},
  'getDoubleValue': {'number'},
  'getBoolValue': {'bool'},
};

Map<String, Map<String, String>> _loadSchema() {
  final list =
      jsonDecode(File('pocketbase/pb_schema.json').readAsStringSync()) as List;
  return {
    for (final c in list)
      c['name'] as String: {
        for (final f in c['fields'] as List) f['name'] as String: f['type'],
      },
  };
}

void main() {
  final schema = _loadSchema();

  test('schema file has the five ResortBook collections', () {
    for (final name in [
      'unit_types',
      'units',
      'stay_types',
      'rates',
      'reservations',
    ]) {
      expect(schema.containsKey(name), isTrue, reason: 'missing $name');
    }
  });

  for (final entry in _modelCollections.entries) {
    test('${entry.key} reads only fields that exist in ${entry.value}', () {
      final source = File(entry.key).readAsStringSync();
      final reads = RegExp(
        r"(getStringValue|getIntValue|getDoubleValue|getBoolValue)\(\s*'(\w+)'",
      ).allMatches(source).toList();
      expect(reads, isNotEmpty, reason: 'no reads found in ${entry.key}');

      final fields = schema[entry.value]!;
      for (final m in reads) {
        final method = m.group(1)!;
        final field = m.group(2)!;
        expect(
          fields.containsKey(field),
          isTrue,
          reason: '${entry.key}: "$field" is not a field of ${entry.value}',
        );
        expect(
          _readers[method]!.contains(fields[field]),
          isTrue,
          reason:
              '${entry.key}: $method("$field") but the field type is '
              '${fields[field]}',
        );
      }
    });
  }

  test('createReservation writes only fields that exist in reservations', () {
    final source = File(
      'lib/services/pocketbase_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('final body = <String, dynamic>{');
    expect(start, greaterThan(-1), reason: 'create body not found');
    final end = source.indexOf('};', start);
    final bodyText = source.substring(start, end);
    final keys = RegExp(
      r"'(\w+)':",
    ).allMatches(bodyText).map((m) => m.group(1)!).toList();
    expect(keys, contains('guestName'));

    final fields = schema['reservations']!;
    for (final key in keys) {
      expect(
        fields.containsKey(key),
        isTrue,
        reason: 'createReservation writes "$key", not a field of reservations',
      );
    }
  });

  test('reservations has the index used by the overlap query', () {
    final list =
        jsonDecode(File('pocketbase/pb_schema.json').readAsStringSync())
            as List;
    final reservations = list.firstWhere((c) => c['name'] == 'reservations');
    expect(
      (reservations['indexes'] as List).join(' '),
      contains('idx_reservations_unit_time'),
    );
  });
}
