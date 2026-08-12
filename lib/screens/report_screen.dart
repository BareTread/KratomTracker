import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../export/csv_export.dart';
import '../models/dosage.dart';
import '../models/strain.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Dosage History',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          Consumer<KratomProvider>(
            builder: (context, provider, _) {
              if (provider.dosages.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Export CSV',
                onPressed: () => _exportCsv(context, provider),
              );
            },
          ),
        ],
      ),
      body: Consumer<KratomProvider>(
        builder: (context, provider, child) {
          final dosages = provider.dosages;
          if (dosages.isEmpty) {
            return Center(
              child: Text(
                'No dosage history yet',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.c.textTertiary,
                    ),
              ),
            );
          }

          final groupedDosages = _groupDosagesByDate(dosages);

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: groupedDosages.length,
            itemBuilder: (context, index) {
              final date = groupedDosages.keys.elementAt(index);
              final dayDosages = groupedDosages[date]!;
              final totalDayAmount = dayDosages.fold<double>(
                0,
                (sum, dosage) => sum + dosage.amount,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index == 0 ||
                      _isNewMonth(
                        date,
                        groupedDosages.keys.elementAt(index - 1),
                      ))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        DateFormat('MMMM yyyy').format(date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.c.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('EEEE, MMM d').format(date),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${totalDayAmount.toStringAsFixed(1)}g total',
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: context.c.textSecondary,
                                      ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final dosage in dayDosages)
                          _buildDosageCard(context, dosage, provider),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDosageCard(
    BuildContext context,
    Dosage dosage,
    KratomProvider provider,
  ) {
    final c = context.c;
    final strain = provider.getStrain(dosage.strainId) ??
        const Strain(
          id: '',
          name: 'Unknown strain',
          code: '?',
          color: 0xFF757575,
          icon: 'Leaf',
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.hairline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDosageDetails(context, dosage, provider),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(strain.color),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strain.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('h:mm a').format(dosage.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${dosage.amount.toStringAsFixed(1)}g',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<DateTime, List<Dosage>> _groupDosagesByDate(List<Dosage> dosages) {
    final grouped = <DateTime, List<Dosage>>{};
    for (final dosage in dosages) {
      final date = DateTime(
        dosage.timestamp.year,
        dosage.timestamp.month,
        dosage.timestamp.day,
      );
      grouped.putIfAbsent(date, () => []).add(dosage);
    }
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key)),
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
    final strain = provider.getStrain(dosage.strainId) ??
        const Strain(
          id: '',
          name: 'Unknown strain',
          code: '?',
          color: 0xFF757575,
          icon: 'Leaf',
        );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(strain.color),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strain.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, MMMM d, y • h:mm a')
                                    .format(dosage.timestamp),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: c.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${dosage.amount.toStringAsFixed(1)}g',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: c.hairline),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditDose(context, dosage, provider);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor:
                                  Colors.red.withValues(alpha: 0.08),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmDelete(context, dosage, provider);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDose(
    BuildContext context,
    Dosage dosage,
    KratomProvider provider,
  ) {
    final c = context.c;
    final TextEditingController amountController = TextEditingController(
      text: dosage.amount.toString(),
    );
    String selectedStrainId = dosage.strainId;
    DateTime selectedTime = dosage.timestamp;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (context, setState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.hairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Edit Dose',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStrainId,
                    decoration: InputDecoration(
                      labelText: 'Strain',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: provider.strains
                        .map(
                          (strain) => DropdownMenuItem(
                            value: strain.id,
                            child: Text(strain.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedStrainId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount (g)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textSecondary,
                          ),
                    ),
                    subtitle: Text(
                      DateFormat('h:mm a, MMM d').format(selectedTime),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    trailing: Icon(
                      Icons.access_time,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedTime),
                      );
                      if (time != null) {
                        setState(() {
                          selectedTime = DateTime(
                            selectedTime.year,
                            selectedTime.month,
                            selectedTime.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final amount = double.tryParse(amountController.text);
                        if (amount != null && amount > 0) {
                          provider.updateDosage(
                            id: dosage.id,
                            strainId: selectedStrainId,
                            amount: amount,
                            timestamp: selectedTime,
                            notes: dosage.notes,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dose updated successfully'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount'),
                            ),
                          );
                        }
                      },
                      child: const Text('Save Changes'),
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

  void _confirmDelete(
    BuildContext context,
    Dosage dosage,
    KratomProvider provider,
  ) {
    final c = context.c;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dose'),
        content: const Text(
          'Are you sure you want to delete this dose? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () {
              provider.deleteDosage(dosage.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Dose deleted'),
                  backgroundColor: c.caution,
                ),
              );
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
