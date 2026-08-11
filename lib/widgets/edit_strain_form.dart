import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import '../models/strain.dart';
import '../theme/app_theme.dart';
import 'leaf_shape_picker.dart';
import 'strain_mark.dart';

class EditStrainForm extends StatefulWidget {
  final Strain strain;

  const EditStrainForm({
    super.key,
    required this.strain,
  });

  @override
  State<EditStrainForm> createState() => _EditStrainFormState();
}

class _EditStrainFormState extends State<EditStrainForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late String _selectedType;
  late _ColorOption _selectedColor;
  late LeafShape _selectedShape;
  late bool _inStock;

  // Define color options similar to AddStrainForm
  final Map<String, List<_ColorOption>> _strainTypes = {
    'Green': [
      const _ColorOption(
        color: Color(0xFF2E7D32),
        name: 'Forest',
        intensity: 'Mild',
      ),
      const _ColorOption(
        color: Color(0xFF4CAF50),
        name: 'Jade',
        intensity: 'Medium',
      ),
      const _ColorOption(
        color: Color(0xFF81C784),
        name: 'Mint',
        intensity: 'Strong',
      ),
    ],
    'Red': [
      const _ColorOption(
        color: Color(0xFFB71C1C),
        name: 'Ruby',
        intensity: 'Mild',
      ),
      const _ColorOption(
        color: Color(0xFFE53935),
        name: 'Crimson',
        intensity: 'Medium',
      ),
      const _ColorOption(
        color: Color(0xFFEF5350),
        name: 'Garnet',
        intensity: 'Strong',
      ),
    ],
    'White': [
      const _ColorOption(
        color: Color(0xFFCFD8DC),
        name: 'Pearl',
        intensity: 'Mild',
      ),
      const _ColorOption(
        color: Color(0xFFB0BEC5),
        name: 'Silver',
        intensity: 'Medium',
      ),
      const _ColorOption(
        color: Color(0xFF90A4AE),
        name: 'Platinum',
        intensity: 'Strong',
      ),
    ],
    'Yellow': [
      const _ColorOption(
        color: Color(0xFFF9A825),
        name: 'Sunrise',
        intensity: 'Mild',
      ),
      const _ColorOption(
        color: Color(0xFFFDD835),
        name: 'Gold',
        intensity: 'Medium',
      ),
      const _ColorOption(
        color: Color(0xFFFFEE58),
        name: 'Amber',
        intensity: 'Strong',
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.strain.name);
    _codeController = TextEditingController(text: widget.strain.code);

    // Initialize selected type and color based on current strain color
    final currentColor = Color(widget.strain.color);
    String foundType = 'Green'; // Default
    _ColorOption foundColor = _strainTypes['Green']![0]; // Default

    // Find matching color in strainTypes
    for (var type in _strainTypes.keys) {
      for (var color in _strainTypes[type]!) {
        if (color.color.toARGB32() == currentColor.toARGB32()) {
          foundType = type;
          foundColor = color;
          break;
        }
      }
    }

    _selectedType = foundType;
    _selectedColor = foundColor;

    // Initialize mark selection from the stored icon. The stored value is
    // already a LeafShape.name after the read migration, but resolve handles
    // any legacy value too.
    _selectedShape = resolveLeafShape(widget.strain.icon, widget.strain.code);
    _inStock = widget.strain.inStock;
  }

  Widget _buildMarkSection(BuildContext context) {
    final c = context.c;
    final strains = Provider.of<KratomProvider>(context, listen: false).strains;
    final colorValue = _selectedColor.color.toARGB32();
    final collision = markCollision(
      strains
          .map(
            (s) => (
              id: s.id,
              name: s.name,
              color: s.color,
              icon: s.icon,
              code: s.code,
            ),
          )
          .toList(growable: false),
      colorValue,
      _selectedShape,
      excludeId: widget.strain.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mark',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        LeafShapePicker(
          selectedShape: _selectedShape,
          color: _selectedColor.color,
          takenShapes: collision.takenForColor,
          onChanged: (shape) => setState(() => _selectedShape = shape),
        ),
        if (collision.ownerName != null) ...[
          const SizedBox(height: 10),
          Text(
            'This colour and mark are already used by '
            '${collision.ownerName}. Pick a free mark, or keep it if you mean '
            'to share them.',
            style: TextStyle(fontSize: 13, color: c.caution),
          ),
        ],
      ],
    );
  }

  // Update the form's build method to include the icon selection:
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Edit Strain',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Strain Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Strain Code'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a code';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Color type selection
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              items: _strainTypes.keys.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                    _selectedColor = _strainTypes[value]![0];
                  });
                }
              },
              decoration: const InputDecoration(labelText: 'Color Type'),
            ),
            const SizedBox(height: 16),
            // Color shade selection
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _strainTypes[_selectedType]!.map((color) {
                  return _buildColorOption(context, color);
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _buildMarkSection(context),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _inStock,
              onChanged: (value) => setState(() => _inStock = value),
              title: const Text('In stock'),
              subtitle: const Text(
                "Turn off when you don't have it on hand. Keeps the history; drops it below the picker line.",
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final provider =
                          Provider.of<KratomProvider>(context, listen: false);
                      provider.updateStrain(
                        widget.strain.id,
                        name: _nameController.text,
                        code: _codeController.text,
                        color: _selectedColor.color.toARGB32(),
                        icon: _selectedShape.name,
                        inStock: _inStock,
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(BuildContext context, _ColorOption color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              color.name,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              color.intensity,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}

class _ColorOption {
  final Color color;
  final String name;
  final String intensity;

  const _ColorOption({
    required this.color,
    required this.name,
    required this.intensity,
  });
}
