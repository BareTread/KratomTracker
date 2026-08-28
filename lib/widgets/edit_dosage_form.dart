import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dosage.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import 'add_dosage_form.dart' show parseDoseAmount, validateDoseAmount;

class EditDosageForm extends StatefulWidget {
  final Dosage dosage;

  const EditDosageForm({
    super.key,
    required this.dosage,
  });

  @override
  State<EditDosageForm> createState() => _EditDosageFormState();
}

class _EditDosageFormState extends State<EditDosageForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late String _selectedStrainId;
  late DateTime _selectedDateTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _formatAmount(widget.dosage.amount),
    );
    _notesController = TextEditingController(
      text: widget.dosage.notes ?? '',
    );
    _selectedStrainId = widget.dosage.strainId;
    _selectedDateTime = widget.dosage.timestamp.toLocal();
  }

  static String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime.isAfter(DateTime.now())
          ? DateTime.now()
          : _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = parseDoseAmount(_amountController.text);
    if (amount == null) return;

    // The date picker clamps to today but the time wheel does not; reject a
    // moved-forward time the same way the add form does.
    if (_selectedDateTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dose time is in the future'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final notesRaw = _notesController.text.trim();
    final provider = context.read<KratomProvider>();
    if (provider.getStrain(_selectedStrainId) == null) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    final positive = context.c.positive;
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    try {
      await provider.updateDosage(
        id: widget.dosage.id,
        strainId: _selectedStrainId,
        amount: amount,
        timestamp: _selectedDateTime,
        notes: notesRaw.isEmpty ? null : notesRaw,
      );
      await HapticFeedback.lightImpact();
      if (!mounted) return;
      navigator.pop();
      messenger?.showSnackBar(
        SnackBar(
          content: const Text('Dose updated'),
          backgroundColor: positive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not update dose')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KratomProvider>();
    final c = context.c;
    final knownStrain = provider.getStrain(_selectedStrainId) != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Dose',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              InputDecorator(
                decoration: _decoration(context, 'Strain').copyWith(
                  errorText: knownStrain ? null : 'Select a strain',
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedStrainId,
                    items: [
                      if (!knownStrain)
                        DropdownMenuItem(
                          value: _selectedStrainId,
                          child: const Text('Unknown strain'),
                        ),
                      ...provider.strains.map((strain) {
                        return DropdownMenuItem(
                          value: strain.id,
                          child: Text(
                            strain.code == strain.name
                                ? strain.code
                                : '${strain.code} — ${strain.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedStrainId = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: _decoration(context, 'Amount (g)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: validateDoseAmount,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: _decoration(context, 'Notes (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateTimeTile(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: DateFormat('MMM d, y').format(_selectedDateTime),
                      onTap: _selectDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateTimeTile(
                      icon: Icons.access_time,
                      label: 'Time',
                      value: DateFormat('h:mm a').format(_selectedDateTime),
                      onTap: _selectTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(BuildContext context, String label) {
    final c = context.c;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: c.surfaceSunken,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.accent, width: 2),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateTimeTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surfaceSunken,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: c.textTertiary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(icon, size: 16, color: c.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
