import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/dosage.dart';
import '../models/strain.dart';
import '../models/effect.dart';

class PdfExportService {
  static Future<void> generateAndShareReport({
    required List<Dosage> dosages,
    required Map<String, Strain> strainMap,
    required List<Effect> effects,
    required String userName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    // Filter dosages by date range if provided
    var filteredDosages = dosages;
    if (startDate != null && endDate != null) {
      filteredDosages = dosages.where((d) {
        return d.timestamp.isAfter(startDate.subtract(const Duration(days: 1))) &&
            d.timestamp.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    }

    // Sort by date
    filteredDosages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Calculate statistics
    final stats = _calculateStats(filteredDosages, strainMap, effects);

    // Add cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => _buildCoverPage(userName, startDate, endDate, stats),
      ),
    );

    // Add summary page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => _buildSummaryPage(stats, strainMap),
      ),
    );

    // Add detailed dosage log
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildDosageLog(filteredDosages, strainMap, effects),
        ],
      ),
    );

    // Share the PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'kratom_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildCoverPage(
    String userName,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic> stats,
  ) {
    final dateRange = startDate != null && endDate != null
        ? '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}'
        : 'All Time';

    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'Kratom Tracker Report',
            style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            userName.isNotEmpty ? userName : 'User Report',
            style: pw.TextStyle(fontSize: 24, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 40),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.teal, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  dateRange,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Generated on ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatBox('Total Dosages', stats['totalDosages'].toString()),
              _buildStatBox('Total Amount', '${stats['totalAmount'].toStringAsFixed(1)}g'),
              _buildStatBox('Days Active', stats['daysActive'].toString()),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryPage(
    Map<String, dynamic> stats,
    Map<String, Strain> strainMap,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary & Analytics',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),

          // Overall statistics
          _buildSection('Overall Statistics', [
            'Total Dosages: ${stats['totalDosages']}',
            'Total Amount: ${stats['totalAmount'].toStringAsFixed(2)}g',
            'Average Dosage: ${stats['avgDosage'].toStringAsFixed(2)}g',
            'Days Active: ${stats['daysActive']}',
            'Average Per Day: ${stats['avgPerDay'].toStringAsFixed(2)}g',
          ]),

          pw.SizedBox(height: 20),

          // Strain breakdown
          _buildSection('Strain Breakdown',
            (stats['strainBreakdown'] as Map<String, dynamic>).entries.map((e) {
              final strain = strainMap[e.key];
              final data = e.value as Map<String, dynamic>;
              return '${strain?.name ?? 'Unknown'}: ${data['count']} doses (${data['total'].toStringAsFixed(1)}g)';
            }).toList(),
          ),

          pw.SizedBox(height: 20),

          // Time patterns
          if (stats['timePatterns'] != null)
            _buildSection('Usage Patterns',
              (stats['timePatterns'] as Map<String, int>).entries.map((e) {
                return '${e.key}: ${e.value} doses';
              }).toList(),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildSection(String title, List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text('• $item', style: const pw.TextStyle(fontSize: 12)),
            )).toList(),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDosageLog(
    List<Dosage> dosages,
    Map<String, Strain> strainMap,
    List<Effect> effects,
  ) {
    final effectsMap = <String, Effect>{};
    for (var effect in effects) {
      effectsMap[effect.dosageId] = effect;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detailed Dosage Log',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 20),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.teal),
              children: [
                _buildTableCell('Date/Time', isHeader: true),
                _buildTableCell('Strain', isHeader: true),
                _buildTableCell('Amount', isHeader: true),
                _buildTableCell('Effects', isHeader: true),
              ],
            ),

            // Data rows
            ...dosages.map((dosage) {
              final strain = strainMap[dosage.strainId];
              final effect = effectsMap[dosage.id];

              final effectsText = effect != null
                  ? 'M:${effect.mood} E:${effect.energy} P:${effect.painRelief}'
                  : 'N/A';

              return pw.TableRow(
                children: [
                  _buildTableCell(DateFormat('MMM d, HH:mm').format(dosage.timestamp)),
                  _buildTableCell(strain?.name ?? 'Unknown'),
                  _buildTableCell('${dosage.amount.toStringAsFixed(1)}g'),
                  _buildTableCell(effectsText),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static Map<String, dynamic> _calculateStats(
    List<Dosage> dosages,
    Map<String, Strain> strainMap,
    List<Effect> effects,
  ) {
    if (dosages.isEmpty) {
      return {
        'totalDosages': 0,
        'totalAmount': 0.0,
        'avgDosage': 0.0,
        'daysActive': 0,
        'avgPerDay': 0.0,
        'strainBreakdown': {},
        'timePatterns': {},
      };
    }

    final totalAmount = dosages.fold(0.0, (sum, d) => sum + d.amount);
    final uniqueDays = <String>{};
    final strainBreakdown = <String, Map<String, dynamic>>{};
    final timePatterns = <String, int>{
      'Morning (6-12)': 0,
      'Afternoon (12-18)': 0,
      'Evening (18-24)': 0,
      'Night (0-6)': 0,
    };

    for (var dosage in dosages) {
      // Track unique days
      uniqueDays.add(DateFormat('yyyy-MM-dd').format(dosage.timestamp));

      // Track strain breakdown
      strainBreakdown.putIfAbsent(dosage.strainId, () => {
        'count': 0,
        'total': 0.0,
      });
      strainBreakdown[dosage.strainId]!['count'] =
          (strainBreakdown[dosage.strainId]!['count'] as int) + 1;
      strainBreakdown[dosage.strainId]!['total'] =
          (strainBreakdown[dosage.strainId]!['total'] as double) + dosage.amount;

      // Track time patterns
      final hour = dosage.timestamp.hour;
      if (hour >= 6 && hour < 12) {
        timePatterns['Morning (6-12)'] = timePatterns['Morning (6-12)']! + 1;
      } else if (hour >= 12 && hour < 18) {
        timePatterns['Afternoon (12-18)'] = timePatterns['Afternoon (12-18)']! + 1;
      } else if (hour >= 18 && hour < 24) {
        timePatterns['Evening (18-24)'] = timePatterns['Evening (18-24)']! + 1;
      } else {
        timePatterns['Night (0-6)'] = timePatterns['Night (0-6)']! + 1;
      }
    }

    return {
      'totalDosages': dosages.length,
      'totalAmount': totalAmount,
      'avgDosage': totalAmount / dosages.length,
      'daysActive': uniqueDays.length,
      'avgPerDay': totalAmount / uniqueDays.length,
      'strainBreakdown': strainBreakdown,
      'timePatterns': timePatterns,
    };
  }
}
