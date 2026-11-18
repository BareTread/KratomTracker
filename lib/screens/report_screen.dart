import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/date_utils.dart';
import '../export/csv_export.dart';
import '../models/dosage.dart';
import '../widgets/sheet_header.dart';
import '../widgets/strain_mark.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_dosage_form.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<KratomProvider>(
            builder: (context, provider, _) {
              if (provider.dosages.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.download, color: c.textSecondary),
                tooltip: 'Export CSV',
                onPressed: () => _exportCsv(context, provider),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Dosage history',
              style: AppType.display(size: 30, color: c.textPrimary),
            ),
          ),
          Expanded(
            child: Consumer<KratomProvider>(
        builder: (context, provider, child) {
          final dosages = provider.dosages;
          if (dosages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No doses logged yet',
                      style: TextStyle(
                        fontFamily: AppType.sans,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Doses you log on Home appear here, newest first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppType.sans,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final groupedDosages = _groupDosagesByDate(dosages);
          final dates = groupedDosages.keys.toList();
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final dayDosages = groupedDosages[date]!;
              final total = dayDosages.fold<double>(
                0, (sum, dosage) => sum + dosage.amount,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index == 0 || _isNewMonth(date, dates[index - 1]))
                      Padding(
                        padding: const EdgeInsets.only(top: 28, bottom: 16),
                        child: Text(
                          DateFormat('MMMM yyyy').format(date),
                          style: sectionLabelStyle(context)
                              .copyWith(color: c.textSecondary, fontSize: 14),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, MMM d').format(date),
                              style: TextStyle(
                                fontFamily: AppType.sans,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${total.toStringAsFixed(1)}g · ${dayDosages.length} ${dayDosages.length == 1 ? 'dose' : 'doses'}',
                            style: TextStyle(
                              fontFamily: AppType.sans,
                              fontSize: 12,
                              color: c.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final dosage in dayDosages)
                      _buildDosageRow(context, dosage, provider),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDosageRow(
    BuildContext context,
    Dosage dosage,
    KratomProvider provider,
  ) {
    final c = context.c;
    final strain = provider.getStrain(dosage.strainId);
    final strainColor = strain == null
        ? c.textSecondary
        : legibleStrainColor(Color(strain.color), Theme.of(context).brightness);
    final note = dosage.notes?.trim();
    const figures = [FontFeature.tabularFigures()];
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDosageDetails(context, dosage, provider),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(
                      DateFormat('h:mm a').format(dosage.timestamp.toLocal()),
                      style: TextStyle(
                        fontFamily: AppType.sans,
                        fontSize: 13,
                        color: c.textSecondary,
                        fontFeatures: figures,
                      ),
                    ),
                  ),
                  if (strain != null) ...[
                    StrainMark(
                      shape: resolveLeafShape(strain.icon, strain.code),
                      color: strainColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          children: [
                            if (strain != null)
                              Text(
                                strain.code,
                                style: TextStyle(
                                  fontFamily: AppType.sans,
                                  fontWeight: FontWeight.w600,
                                  color: strainColor,
                                ),
                              ),
                            Text(
                              strain?.name ?? 'Unknown strain',
                              style: TextStyle(
                                fontFamily: AppType.sans,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (note != null && note.isNotEmpty)
                          Text(
                            note,
                            style: TextStyle(
                              fontFamily: AppType.sans,
                              fontSize: 12,
                              color: c.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${dosage.amount.toStringAsFixed(1)}g',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: AppType.sans,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                      fontFeatures: figures,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<DateTime, List<Dosage>> _groupDosagesByDate(List<Dosage> dosages) {
    final grouped = <DateTime, List<Dosage>>{};
    for (final dosage in dosages) {
      final date = startOfDay(dosage.timestamp);
      grouped.putIfAbsent(date, () => []).add(dosage);
    }
    for (final day in grouped.values) {
      day.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  bool _isNewMonth(DateTime current, DateTime previous) =>
      current.year != previous.year || current.month != previous.month;

  void _showDosageDetails(
    BuildContext context,
    Dosage dosage,
    KratomProvider provider,
  ) {
    final c = context.c;
    final localTimestamp = dosage.timestamp.toLocal();
    final strain = provider.getStrain(dosage.strainId);
    final name = strain?.name ?? 'Unknown strain';
    final identity = strain == null ? name : '${strain.code} · $name';
    final note = dosage.notes?.trim();

    showAppSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader(
                title: '${dosage.amount.toStringAsFixed(1)}g',
                subtitle: '$identity · ${DateFormat('EEE d MMM, h:mm a').format(localTimestamp)}',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SheetHeader.inset),
                child: Column(
                  children: [
                    _detailRow(context, 'Strain', name),
                    _detailRow(
                      context, 'Date',
                      DateFormat('EEEE, MMMM d, y').format(localTimestamp),
                    ),
                    _detailRow(
                      context, 'Time',
                      DateFormat('h:mm a').format(localTimestamp),
                    ),
                    if (note != null && note.isNotEmpty)
                      _detailRow(context, 'Note', note),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.accent,
                            side: BorderSide(color: c.accent),
                            minimumSize: const Size(80, 48),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _showEditDose(context, dosage);
                          },
                          child: const Text('Edit'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: c.caution,
                            minimumSize: const Size(80, 48),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _confirmDelete(context, dosage, provider);
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontFamily: AppType.sans, color: c.textTertiary)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontFamily: AppType.sans, color: c.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _showEditDose(BuildContext context, Dosage dosage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditDosageForm(dosage: dosage),
    );
  }

  void _confirmDelete(
    BuildContext context,
    Dosage dosage,
    KratomProvider provider,
  ) {
    final c = context.c;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete dose?'),
        content: Text(
          'Delete ${dosage.amount.toStringAsFixed(1)}g of ${provider.getStrain(dosage.strainId)?.name ?? 'Unknown strain'} at ${DateFormat('h:mm a').format(dosage.timestamp.toLocal())}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              'Delete',
              style: TextStyle(color: context.c.caution),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await provider.deleteDosage(dosage.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Dose deleted'),
                    backgroundColor: c.caution,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to delete dose: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, KratomProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await shareDosagesCsv(
        dosages: provider.dosages,
        strains: provider.strains,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('CSV export ready to share')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('CSV export failed: $e')),
      );
    }
  }
}
