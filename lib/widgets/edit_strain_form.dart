import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import '../models/strain.dart';

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
  late _IconOption _selectedIcon;

  // Define color options similar to AddStrainForm
  final Map<String, List<_ColorOption>> _strainTypes = {
    'Green': [
      _ColorOption(
        color: const Color(0xFF2E7D32),
        name: 'Forest',
        intensity: 'Mild',
      ),
      _ColorOption(
        color: const Color(0xFF4CAF50),
        name: 'Jade',
        intensity: 'Medium',
      ),
      _ColorOption(
        color: const Color(0xFF81C784),
        name: 'Mint',
        intensity: 'Strong',
      ),
    ],
    'Red': [
      _ColorOption(
        color: const Color(0xFFB71C1C),
        name: 'Ruby',
        intensity: 'Mild',
      ),
      _ColorOption(
        color: const Color(0xFFE53935),
        name: 'Crimson',
        intensity: 'Medium',
      ),
      _ColorOption(
        color: const Color(0xFFEF5350),
        name: 'Garnet',
        intensity: 'Strong',
      ),
    ],
    'White': [
      _ColorOption(
        color: const Color(0xFFCFD8DC),
        name: 'Pearl',
        intensity: 'Mild',
      ),
      _ColorOption(
        color: const Color(0xFFB0BEC5),
        name: 'Silver',
        intensity: 'Medium',
      ),
      _ColorOption(
        color: const Color(0xFF90A4AE),
        name: 'Platinum',
        intensity: 'Strong',
      ),
    ],
    'Yellow': [
      _ColorOption(
        color: const Color(0xFFF9A825),
        name: 'Sunrise',
        intensity: 'Mild',
      ),
      _ColorOption(
        color: const Color(0xFFFDD835),
        name: 'Gold',
        intensity: 'Medium',
      ),
      _ColorOption(
        color: const Color(0xFFFFEE58),
        name: 'Amber',
        intensity: 'Strong',
      ),
    ],
  };

  // Define icon options similar to AddStrainForm
  final Map<String, List<_IconOption>> _iconTypes = {
    'Leaf': [
      _IconOption(
        name: 'Leaf',
        icon: Icons.local_florist,
      ),
      _IconOption(
        name: 'Natural',
        icon: Icons.eco,
      ),
      _IconOption(
        name: 'Plant',
        icon: Icons.grass,
      ),
    ],
    'Nature': [
      _IconOption(
        name: 'Organic',
        icon: Icons.spa,
      ),
      _IconOption(
        name: 'Growth',
        icon: Icons.trending_up,
      ),
      _IconOption(
        name: 'Nature',
        icon: Icons.nature,
      ),
    ],
    'Other': [
      _IconOption(
        name: 'Star',
        icon: Icons.star,
      ),
      _IconOption(
        name: 'Circle',
        icon: Icons.circle,
      ),
      _IconOption(
        name: 'Diamond',
        icon: Icons.diamond,
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
        if (color.color.value == currentColor.value) {
          foundType = type;
          foundColor = color;
          break;
        }
      }
    }

    _selectedType = foundType;
    _selectedColor = foundColor;

    // Initialize icon selection
    String foundIconType = 'Leaf'; // Default
    _IconOption? foundIconOption;

    // Find matching icon in iconTypes
    for (var type in _iconTypes.keys) {
      for (var iconOption in _iconTypes[type]!) {
        if (iconOption.name == widget.strain.icon) {
          foundIconType = type;
          foundIconOption = iconOption;
          break;
        }
      }
      if (foundIconOption != null) break;
    }

    _selectedType = foundIconType;
    _selectedIcon = foundIconOption ?? _iconTypes['Leaf']![0];
  }

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
              value: _selectedType,
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
            // Icon selection
            DropdownButtonFormField<String>(
              value: _selectedIcon.name,
              items: _iconTypes.keys.map((String icon) {
                return DropdownMenuItem<String>(
                  value: icon,
                  child: Text(icon),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedIcon = _iconTypes[value]![0];
                  });
                }
              },
              decoration: const InputDecoration(labelText: 'Icon'),
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
                      final provider = Provider.of<KratomProvider>(context, listen: false);
                      provider.updateStrain(
                        widget.strain.id,
                        name: _nameController.text,
                        code: _codeController.text,
                        color: _selectedColor.color.value,
                        icon: _selectedIcon.name,
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
                color: Colors.white.withOpacity(0.8),
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

class _IconOption {
  final String name;
  final IconData icon;

  const _IconOption({
    required this.name,
    required this.icon,
  });
} 