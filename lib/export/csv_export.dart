import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dosage.dart';
import '../models/strain.dart';

/// One row per dose, oldest first. UTF-8 with a BOM so Excel opens it
/// correctly, RFC 4180 quoting, ISO-8601 timestamps.
///
/// Pure and synchronous so it is unit-testable without a widget tree.
String exportDosagesCsv({
  required List<Dosage> dosages,
  required List<Strain> strains,
}) {
  final strainById = {for (final s in strains) s.id: s};

  final ordered = [...dosages]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final buffer = StringBuffer()
    ..write('\uFEFF') // UTF-8 BOM
    ..writeln(_header);

  for (final dose in ordered) {
    final strain = strainById[dose.strainId];
    buffer.writeln(_row(dose, strain));
  }

  return buffer.toString();
}

const _header =
    'date,time,iso_timestamp,strain_code,strain_name,amount_g,notes';

String _row(Dosage dose, Strain? strain) {
  final fields = <String>[
    DateFormat('yyyy-MM-dd').format(dose.timestamp),
    DateFormat('HH:mm').format(dose.timestamp),
    dose.timestamp.toIso8601String(),
    strain?.code ?? '???',
    strain?.name ?? 'Unknown strain',
    _formatAmount(dose.amount),
    dose.notes ?? '',
  ];
  return fields.map(_quote).join(',');
}

String _formatAmount(double amount) {
  if (amount == amount.roundToDouble()) return amount.toStringAsFixed(1);
  return amount.toStringAsFixed(2);
}

/// RFC 4180: quote any field containing a comma, double quote, or line break;
/// escape embedded double quotes by doubling them.
String _quote(String field) {
  if (field.contains(',') ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}

/// Writes the CSV to a temp file and hands it to the OS share sheet.
/// Returns the path that was shared.
Future<String> shareDosagesCsv({
  required List<Dosage> dosages,
  required List<Strain> strains,
}) async {
  final csv = exportDosagesCsv(
    dosages: dosages,
    strains: strains,
  );

  final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final filename = 'kratom_tracker_export_$stamp.csv';

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(utf8.encode(csv), flush: true);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Kratom Tracker CSV export',
  );

  debugPrint('CSV exported to ${file.path}');
  return file.path;
}
