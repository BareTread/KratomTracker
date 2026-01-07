import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import 'package:intl/intl.dart';
import '../constants/icons.dart';
import '../widgets/add_strain_form.dart';

class AddDosageForm extends StatefulWidget {
  final String? preselectedStrainId;

  const AddDosageForm({
    super.key,
    this.preselectedStrainId,
  });

  @override
  State<AddDosageForm> createState() => _AddDosageFormState();
}

class _AddDosageFormState extends State<AddDosageForm> {
  // Step tracking
  bool _strainSelected = false;
  late String? _selectedStrainId;
  
  @override
  void initState() {
    super.initState();
    _selectedStrainId = widget.preselectedStrainId;
    if (_selectedStrainId != null) {
      _strainSelected = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KratomProvider>();
    final strains = provider.strains;

    if (strains.isEmpty) {
      return _buildEmptyStrainsState();
    }

    return _strainSelected
        ? _DosageDetailsForm(
            strainId: _selectedStrainId!,
            onBack: () => setState(() => _strainSelected = false),
          )
        : _StrainSelectionView(
            onStrainSelected: (strainId) {
              setState(() {
                _selectedStrainId = strainId;
                _strainSelected = true;
              });
            },
          );
  }

  Widget _buildEmptyStrainsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_florist_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Strains Added',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first strain to start tracking doses',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);  // Close add dose sheet
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const AddStrainForm(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Strain'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Step 1: Strain Selection
class _StrainSelectionView extends StatelessWidget {
  final Function(String) onStrainSelected;

  const _StrainSelectionView({
    required this.onStrainSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        final strains = provider.strains;
        final dosages = provider.dosages;
        
        // Create a map of strain IDs to their last usage time
        final lastUsageMap = <String, DateTime>{};
        for (var strain in strains) {
          final strainDosages = dosages.where((d) => d.strainId == strain.id);
          if (strainDosages.isNotEmpty) {
            lastUsageMap[strain.id] = strainDosages
                .reduce((a, b) => 
                    a.timestamp.isAfter(b.timestamp) ? a : b)
                .timestamp;
          } else {
            lastUsageMap[strain.id] = DateTime.fromMillisecondsSinceEpoch(0);
          }
        }

        // Calculate 30-day consumption for each strain
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        final thirtyDayTotals = <String, double>{};
        for (var strain in strains) {
          thirtyDayTotals[strain.id] = dosages
              .where((d) => d.strainId == strain.id && d.timestamp.isAfter(thirtyDaysAgo))
              .fold(0.0, (sum, d) => sum + d.amount);
        }

        // Calculate rotation scores (higher = better rotation choice)
        final rotationScores = <String, double>{};
        for (var strain in strains) {
          final lastUsed = lastUsageMap[strain.id]!;
          final daysSinceUse = lastUsed.year == 1970 
              ? 365.0
              : DateTime.now().difference(lastUsed).inDays.toDouble();
          
          final consumptionScore = 1.0 - (thirtyDayTotals[strain.id]! / 500.0).clamp(0.0, 1.0);
          rotationScores[strain.id] = (daysSinceUse * 0.7) + (consumptionScore * 100 * 0.3);
        }

        // Sort strains by rotation score (highest first)
        final sortedStrains = strains.toList()
          ..sort((a, b) => rotationScores[b.id]!.compareTo(rotationScores[a.id]!));

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_pharmacy_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Strain',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Top 3 strains recommended for rotation',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),

              // Strain List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: sortedStrains.length,
                  itemBuilder: (context, index) {
                    final strain = sortedStrains[index];
                    final lastUsed = lastUsageMap[strain.id]!;
                    final isRecommended = index < 3;
                    final monthlyTotal = thirtyDayTotals[strain.id]!;
                    final lastUsedText = lastUsed.year == 1970 
                        ? 'Never used'
                        : '${_getLastUsedText(lastUsed)} · ${monthlyTotal.toStringAsFixed(0)}g/mo';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isRecommended 
                            ? Color(strain.color).withOpacity(0.15)
                            : Colors.grey[900]?.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => onStrainSelected(strain.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Strain Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Color(strain.color).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    strainIcons[strain.icon] ?? Icons.local_florist,
                                    color: Color(strain.color),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Strain Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            strain.code,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (isRecommended) ...[
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.star_rounded,
                                              size: 16,
                                              color: Color(strain.color),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastUsedText,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getLastUsedText(DateTime lastUsed) {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);

    if (difference.inDays > 30) {
      return 'Last used ${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return 'Last used ${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return 'Last used ${difference.inHours} hours ago';
    } else {
      return 'Used recently';
    }
  }
}

// First, create the DosageDetailsForm widget
class _DosageDetailsForm extends StatefulWidget {
  final String strainId;
  final VoidCallback onBack;

  const _DosageDetailsForm({
    required this.strainId,
    required this.onBack,
  });

  @override
  State<_DosageDetailsForm> createState() => _DosageDetailsFormState();
}

class _DosageDetailsFormState extends State<_DosageDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with back button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack,
                    ),
                    const Text(
                      'Add Dose',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Amount Input
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    suffixText: 'g',
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[850] // Slightly lighter than background in dark mode
                        : Colors.grey[100], // Light grey in light mode
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]! // Visible border in dark mode
                            : Colors.grey[300]!, // Subtle border in light mode
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]! // Visible border in dark mode
                            : Colors.grey[300]!, // Subtle border in light mode
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Date & Time Selection
                Row(
                  children: [
                    Expanded(
                      child: _buildDateTimeButton(
                        icon: Icons.calendar_today,
                        label: DateFormat('MMM d, y').format(_selectedDateTime),
                        onPressed: () => _selectDate(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDateTimeButton(
                        icon: Icons.access_time,
                        label: DateFormat('h:mm a').format(_selectedDateTime),
                        onPressed: () => _selectTime(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Notes Input
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[850] // Slightly lighter than background in dark mode
                        : Colors.grey[100], // Light grey in light mode
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]! // Visible border in dark mode
                            : Colors.grey[300]!, // Subtle border in light mode
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]! // Visible border in dark mode
                            : Colors.grey[300]!, // Subtle border in light mode
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ACC1),  // Teal accent color
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final amount = double.tryParse(_amountController.text);
                      if (amount != null && amount > 0) {
                        Provider.of<KratomProvider>(context, listen: false)
                            .addDosage(widget.strainId, amount, _selectedDateTime);
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text(
                    'Add Dose',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: isDark ? Colors.grey[850] : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
} 