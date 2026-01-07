import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';

class AddStrainForm extends StatefulWidget {
  const AddStrainForm({super.key});

  @override
  State<AddStrainForm> createState() => _AddStrainFormState();
}

class _AddStrainFormState extends State<AddStrainForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  int _selectedIcon = 0;

  // Updated color palette with more distinct shades
  final Map<String, List<_ColorOption>> _strainTypes = {
    'Green': [
      _ColorOption(
        color: const Color(0xFF2E7D32), // Darker forest green
        name: 'Forest',
        intensity: 'Mild',
      ),
      _ColorOption(
        color: const Color(0xFF4CAF50), // Medium green
        name: 'Jade',
        intensity: 'Medium',
      ),
      _ColorOption(
        color: const Color(0xFF81C784), // Light green
        name: 'Mint',
        intensity: 'Strong',
      ),
    ],
    'Red': [
      _ColorOption(
        color: const Color(0xFFB71C1C), // Deep red
        name: 'Ruby',
        intensity: 'Mild',
      ),
      _ColorOption(
        color: const Color(0xFFE53935), // Bright red
        name: 'Crimson',
        intensity: 'Medium',
      ),
      _ColorOption(
        color: const Color(0xFFEF5350), // Light red
        name: 'Garnet',
        intensity: 'Strong',
      ),
    ],
    'White': [
      _ColorOption(
        color: const Color(0xFFE3F2FD), // Light blue-white
        name: 'Pearl',
        intensity: 'Mild',
      ),
      _ColorOption(
        color: const Color(0xFFBBDEFB), // Brighter blue-white
        name: 'Silver',
        intensity: 'Medium',
      ),
      _ColorOption(
        color: const Color(0xFF90CAF9), // More vibrant blue
        name: 'Platinum',
        intensity: 'Strong',
      ),
    ],
    'Yellow': [
      _ColorOption(
        color: const Color(0xFFF9A825), // Deep gold
        name: 'Sunrise',
        intensity: 'Mild',
      ),
      _ColorOption(
        color: const Color(0xFFFDD835), // Bright yellow
        name: 'Gold',
        intensity: 'Medium',
      ),
      _ColorOption(
        color: const Color(0xFFFFEE58), // Light yellow
        name: 'Amber',
        intensity: 'Strong',
      ),
    ],
  };

  String _selectedType = 'Green';
  _ColorOption? _selectedColor;

  final List<_IconOption> _icons = [
    _IconOption(
      icon: Icons.local_florist_outlined,
      name: 'Plant',
    ),
    _IconOption(
      icon: Icons.eco_outlined,
      name: 'Leaf',
    ),
    _IconOption(
      icon: Icons.grass_outlined,
      name: 'Natural',
    ),
    _IconOption(
      icon: Icons.spa_outlined,
      name: 'Organic',
    ),
    _IconOption(
      icon: Icons.forest_outlined,
      name: 'Forest',
    ),
    _IconOption(
      icon: Icons.nature_outlined,
      name: 'Nature',
    ),
    _IconOption(
      icon: Icons.park_outlined,
      name: 'Park',
    ),
    _IconOption(
      icon: Icons.yard_outlined,
      name: 'Yard',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = _strainTypes[_selectedType]![0];
  }

  // Add smooth color transition animation
  Widget _buildIconOption(BuildContext context, _IconOption icon, int index) {
    final isSelected = _selectedIcon == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () => setState(() => _selectedIcon = index),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isSelected
                ? _selectedColor!.color.withOpacity(0.2)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? _selectedColor!.color
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon.icon,
                color: isSelected
                    ? _selectedColor!.color
                    : Theme.of(context).iconTheme.color,
              ),
              const SizedBox(height: 4),
              Text(
                icon.name,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? _selectedColor!.color
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add smooth color preview animation
  Widget _buildColorOption(BuildContext context, _ColorOption color) {
    final isSelected = _selectedColor == color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: GestureDetector(
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
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                color.name,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              Text(
                color.intensity,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.8),
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 2,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Strain',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Strain Name',
                    hintText: 'Enter strain name',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Strain Code',
                    hintText: '2-4 letters',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a code';
                    }
                    if (value.length < 2 || value.length > 4) {
                      return 'Code must be 2-4 letters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Icon',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _icons.length,
                    itemBuilder: (context, index) {
                      final icon = _icons[index];
                      return _buildIconOption(context, icon, index);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Color',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                for (var type in _strainTypes.entries) ...[
                  Row(
                    children: [
                      Radio<String>(
                        value: type.key,
                        groupValue: _selectedType,
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                            _selectedColor = _strainTypes[value]![0];
                          });
                        },
                      ),
                      Text(type.key),
                    ],
                  ),
                  if (_selectedType == type.key)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: type.value.map((color) {
                        return _buildColorOption(context, color);
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final provider = Provider.of<KratomProvider>(context, listen: false);
                        provider.addStrain(
                          _nameController.text,
                          _codeController.text,
                          _selectedColor!.color.value,
                          _icons[_selectedIcon].name,
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Add Strain',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
  final IconData icon;
  final String name;

  const _IconOption({
    required this.icon,
    required this.name,
  });
} 