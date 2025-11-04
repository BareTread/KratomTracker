import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/dosage.dart';
import '../models/strain.dart';
import '../models/effect.dart';

class CsvExportService {
  static Future<String> generateDosagesCsv(
    List<Dosage> dosages,
    Map<String, Strain> strainMap,
  ) async {
    final List<List<dynamic>> rows = [
      // Header row
      ['Date', 'Time', 'Strain', 'Amount (g)', 'Notes'],
    ];

    // Sort dosages by timestamp (newest first)
    final sortedDosages = List<Dosage>.from(dosages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Add data rows
    for (var dosage in sortedDosages) {
      final strain = strainMap[dosage.strainId];
      rows.add([
        DateFormat('yyyy-MM-dd').format(dosage.timestamp),
        DateFormat('HH:mm').format(dosage.timestamp),
        strain?.name ?? 'Unknown',
        dosage.amount.toStringAsFixed(2),
        dosage.notes ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static Future<String> generateDetailedCsv(
    List<Dosage> dosages,
    Map<String, Strain> strainMap,
    List<Effect> effects,
  ) async {
    final List<List<dynamic>> rows = [
      // Header row
      [
        'Date',
        'Time',
        'Strain',
        'Strain Type',
        'Amount (g)',
        'Mood (1-5)',
        'Energy (1-5)',
        'Pain Relief (1-5)',
        'Anxiety (1-5)',
        'Focus (1-5)',
        'Notes',
      ],
    ];

    // Sort dosages by timestamp (newest first)
    final sortedDosages = List<Dosage>.from(dosages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Create effects map for quick lookup
    final effectsMap = <String, Effect>{};
    for (var effect in effects) {
      effectsMap[effect.dosageId] = effect;
    }

    // Add data rows
    for (var dosage in sortedDosages) {
      final strain = strainMap[dosage.strainId];
      final effect = effectsMap[dosage.id];

      rows.add([
        DateFormat('yyyy-MM-dd').format(dosage.timestamp),
        DateFormat('HH:mm').format(dosage.timestamp),
        strain?.name ?? 'Unknown',
        strain?.code ?? '',
        dosage.amount.toStringAsFixed(2),
        effect?.mood?.toString() ?? '',
        effect?.energy?.toString() ?? '',
        effect?.painRelief?.toString() ?? '',
        effect?.anxiety?.toString() ?? '',
        effect?.focus?.toString() ?? '',
        dosage.notes ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static Future<String> generateStrainAnalyticsCsv(
    List<Strain> strains,
    Map<String, Map<String, dynamic>> strainAnalytics,
  ) async {
    final List<List<dynamic>> rows = [
      // Header row
      [
        'Strain Name',
        'Type',
        'Total Uses',
        'Avg Amount (g)',
        'Min Amount (g)',
        'Max Amount (g)',
        'Avg Mood',
        'Avg Energy',
        'Avg Pain Relief',
        'Effectiveness Score',
      ],
    ];

    // Add data rows
    for (var strain in strains) {
      final analytics = strainAnalytics[strain.id];
      if (analytics == null) continue;

      final optimalDosage = analytics['optimalDosage'] as Map<String, dynamic>?;
      final avgEffects = analytics['averageEffects'] as Map<String, dynamic>?;

      rows.add([
        strain.name,
        strain.code,
        analytics['totalUses']?.toString() ?? '0',
        optimalDosage?['avg']?.toStringAsFixed(2) ?? '',
        optimalDosage?['min']?.toStringAsFixed(2) ?? '',
        optimalDosage?['max']?.toStringAsFixed(2) ?? '',
        avgEffects?['mood']?.toStringAsFixed(1) ?? '',
        avgEffects?['energy']?.toStringAsFixed(1) ?? '',
        avgEffects?['pain_relief']?.toStringAsFixed(1) ?? '',
        analytics['effectivenessScore']?.toStringAsFixed(1) ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static Future<String> generateMonthlySummaryCsv(
    List<Dosage> dosages,
  ) async {
    // Group dosages by month
    final monthlyData = <String, List<Dosage>>{};
    for (var dosage in dosages) {
      final monthKey = DateFormat('yyyy-MM').format(dosage.timestamp);
      monthlyData.putIfAbsent(monthKey, () => []).add(dosage);
    }

    final List<List<dynamic>> rows = [
      // Header row
      [
        'Month',
        'Total Dosages',
        'Total Amount (g)',
        'Avg Amount (g)',
        'Days Active',
        'Avg Per Day (g)',
      ],
    ];

    // Sort months
    final sortedMonths = monthlyData.keys.toList()..sort((a, b) => b.compareTo(a));

    // Add data rows
    for (var monthKey in sortedMonths) {
      final monthDosages = monthlyData[monthKey]!;
      final totalAmount = monthDosages.fold(0.0, (sum, d) => sum + d.amount);
      final avgAmount = totalAmount / monthDosages.length;

      // Calculate days active
      final uniqueDays = <String>{};
      for (var dosage in monthDosages) {
        uniqueDays.add(DateFormat('yyyy-MM-dd').format(dosage.timestamp));
      }

      rows.add([
        DateFormat('MMMM yyyy').format(DateTime.parse('$monthKey-01')),
        monthDosages.length.toString(),
        totalAmount.toStringAsFixed(2),
        avgAmount.toStringAsFixed(2),
        uniqueDays.length.toString(),
        (totalAmount / uniqueDays.length).toStringAsFixed(2),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static Future<void> exportAndShare(String csvContent, String filename) async {
    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$filename';
      final file = File(path);
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(path)],
        subject: filename,
      );
    } catch (e) {
      rethrow;
    }
  }
}
