import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/export/csv_export.dart';
import 'package:kratom_tracker_plus/models/dosage.dart';
import 'package:kratom_tracker_plus/models/strain.dart';

void main() {
  group('exportDosagesCsv', () {
    test('emits a UTF-8 BOM and the exact header row', () {
      final csv = exportDosagesCsv(dosages: [], strains: []);
      expect(csv.startsWith('\uFEFF'), isTrue);
      final lines = const LineSplitter().convert(csv);
      final firstLine = lines.first.replaceFirst('\uFEFF', '');
      expect(
        firstLine,
        'date,time,iso_timestamp,strain_code,strain_name,amount_g,notes',
      );
    });

    test('quotes a note containing a comma, a quote, and a newline', () {
      final dose = Dosage(
        id: 'd1',
        strainId: 's1',
        amount: 2.5,
        timestamp: DateTime(2025, 3, 1, 8, 30),
        notes: 'A note, with a "quote" and a\nnewline',
      );
      final csv = exportDosagesCsv(
        dosages: [dose],
        strains: [
          const Strain(
            id: 's1',
            name: 'Maeng Da',
            code: 'MD',
            color: 1,
            icon: 'Leaf',
          ),
        ],
      );

      // The note field must be wrapped in quotes, with the embedded quote
      // doubled and the newline preserved inside the quotes.
      expect(csv, contains('"A note, with a ""quote"" and a\nnewline"'));
      // One data row, so the parsed CSV is header + one record.
      final records = _parseCsv(csv);
      expect(records, hasLength(2));
      expect(records[1][6], 'A note, with a "quote" and a\nnewline');
    });

    test('every data row has the same column count as the header', () {
      final doses = [
        Dosage(
          id: 'd1',
          strainId: 's1',
          amount: 1,
          timestamp: DateTime(2025, 3, 1, 8),
          notes: null,
        ),
        Dosage(
          id: 'd2',
          strainId: 's1',
          amount: 3.5,
          timestamp: DateTime(2025, 3, 2, 9, 15),
          notes: 'plain note',
        ),
        Dosage(
          id: 'd3',
          strainId: 's1',
          amount: 2,
          timestamp: DateTime(2025, 3, 3, 20),
          notes: 'comma, note',
        ),
      ];
      final csv = exportDosagesCsv(
        dosages: doses,
        strains: [
          const Strain(
            id: 's1',
            name: 'Maeng Da',
            code: 'MD',
            color: 1,
            icon: 'Leaf',
          ),
        ],
      );

      // Parse the CSV respecting quoted fields, then verify column counts.
      final records = _parseCsv(csv);
      final header = records.first;
      expect(header, hasLength(7));
      for (final row in records.skip(1)) {
        expect(row, hasLength(header.length), reason: 'row: $row');
      }
    });

    test('rows are sorted oldest first', () {
      final doses = [
        Dosage(
          id: 'late',
          strainId: 's1',
          amount: 1,
          timestamp: DateTime(2025, 3, 10),
        ),
        Dosage(
          id: 'early',
          strainId: 's1',
          amount: 1,
          timestamp: DateTime(2025, 3, 1),
        ),
        Dosage(
          id: 'mid',
          strainId: 's1',
          amount: 1,
          timestamp: DateTime(2025, 3, 5),
        ),
      ];
      final csv = exportDosagesCsv(
        dosages: doses,
        strains: [
          const Strain(
            id: 's1',
            name: 'Maeng Da',
            code: 'MD',
            color: 1,
            icon: 'Leaf',
          ),
        ],
      );
      final records = _parseCsv(csv);
      final ids = records.skip(1).map((r) => r[2]).toList(); // iso_timestamp
      expect(ids, [
        DateTime(2025, 3, 1).toIso8601String(),
        DateTime(2025, 3, 5).toIso8601String(),
        DateTime(2025, 3, 10).toIso8601String(),
      ]);
    });

    test('a dose whose strain was deleted exports a safe placeholder', () {
      final dose = Dosage(
        id: 'orphan',
        strainId: 'gone',
        amount: 2,
        timestamp: DateTime(2025, 3, 1, 8),
      );
      // No strain list at all — strain id references nothing.
      final csv = exportDosagesCsv(
        dosages: [dose],
        strains: const [],
      );
      expect(csv, isNot(throwsA(anything)));
      final records = _parseCsv(csv);
      final row = records[1];
      expect(row[3], '???'); // strain_code placeholder
      expect(row[4], 'Unknown strain'); // strain_name placeholder
    });
  });
}

/// Minimal RFC 4180 CSV parser sufficient for these tests.
List<List<String>> _parseCsv(String input) {
  final source = input.startsWith('\uFEFF') ? input.substring(1) : input;
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else {
      if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        row.add(field.toString());
        field.clear();
      } else if (ch == '\n') {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else if (ch == '\r') {
        // Ignore — handled by \n.
      } else {
        field.write(ch);
      }
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
