import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/kratom_provider.dart';
import '../models/dosage.dart';

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

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.dosage.amount.toString(),
    );
    _notesController = TextEditingController(
      text: widget.dosage.notes ?? '',
    );
    _selectedStrainId = widget.dosage.strainId;
    _selectedDateTime = widget.dosage.timestamp;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KratomProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Dose',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _selectedStrainId,
            decoration: InputDecoration(
              labelText: 'Strain',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: provider.strains.map((strain) {
              return DropdownMenuItem(
                value: strain.id,
                child: Text(strain.name),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedStrainId = value);
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount (g)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'Please enter a valid amount';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Time',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              DateFormat('h:mm a, MMM d').format(_selectedDateTime),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.access_time,
              color: Theme.of(context).primaryColor,
            ),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
              );
              if (time != null) {
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
                if (_formKey.currentState!.validate()) {
                  final amount = double.tryParse(_amountController.text);
                  if (amount != null && amount > 0) {
                    provider.updateDosage(
                      id: widget.dosage.id,
                      strainId: _selectedStrainId,
                      amount: amount,
                      timestamp: _selectedDateTime,
                      notes: _notesController.text.isEmpty ? null : _notesController.text,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dose updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
} 