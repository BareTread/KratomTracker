import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import 'leaf_shape_picker.dart';
import 'strain_mark.dart';

class AddStrainForm extends StatefulWidget {
  const AddStrainForm({super.key});

  @override
  State<AddStrainForm> createState() => _AddStrainFormState();
}

class _AddStrainFormState extends State<AddStrainForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  LeafShape _selectedShape = LeafShape.lance;

  // Updated color palette with more distinct shades
  final Map<String, List<_ColorOption>> _strainTypes = {
    'Green': [
      const _ColorOption(
        color: Color(0xFF2E7D32), // Darker forest green
        name: 'Forest',
        intensity: 'Mild',
      ),
      const _ColorOption(
        color: Color(0xFF4CAF50), // Medium green
        name: 'Jade',
        intensity: 'Medium',
      ),
      const _ColorOption(
        color: Color(0xFF81C784), // Light green
        name: 'Mint',
        intensity: 'Strong',
      ),
    ],
    'Red': [
      const _ColorOption(
        color: Color(0xFFB71C1C), // Deep red
        name: 'Ruby',
        intensity: 'Mild',
      ),
      const _ColorOption(
        color: Color(0xFFE53935), // Bright red
        name: 'Crimson',
        intensity: 'Medium',
      ),
      const _ColorOption(
        color: Color(0xFFEF5350), // Light red
        name: 'Garnet',
        intensity: 'Strong',
      ),
    ],
    'White': [
      const _ColorOption(
        color: Color(0xFFE3F2FD), // Light blue-white
        name: 'Pearl',
        intensity: 'Mild',
      ),
      const _ColorOption(
        color: Color(0xFFBBDEFB), // Brighter blue-white
        name: 'Silver',
        intensity: 'Medium',
      ),
      const _ColorOption(
        color: Color(0xFF90CAF9), // More vibrant blue
        name: 'Platinum',
        intensity: 'Strong',
      ),
    ],
    'Yellow': [
      const _ColorOption(
        color: Color(0xFFF9A825), // Deep gold
        name: 'Sunrise',
        intensity: 'Mild',
      ),
      const _ColorOption(
        color: Color(0xFFFDD835), // Bright yellow
        name: 'Gold',
        intensity: 'Medium',
      ),
      const _ColorOption(
        color: Color(0xFFFFEE58), // Light yellow
        name: 'Amber',
        intensity: 'Strong',
      ),
    ],
  };

  String _selectedType = 'Green';
  _ColorOption? _selectedColor;
  bool _inStock = true;

  @override
  void initState() {
    super.initState();
    _selectedColor = _strainTypes[_selectedType]![0];
  }

  Widget _buildMarkSection(BuildContext context) {
    final c = context.c;
    final strains = Provider.of<KratomProvider>(context, listen: false).strains;
    final colorValue = _selectedColor!.color.toARGB32();
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
          color: _selectedColor!.color,
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
                      color: color.color.withValues(alpha: 0.4),
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
                  color: Colors.white.withValues(alpha: 0.8),
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
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    if (value == null || value.trim().isEmpty) {
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
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Please enter a code';
                    }
                    if (trimmed.length < 2 || trimmed.length > 4) {
                      return 'Code must be 2-4 letters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _buildMarkSection(context),
                const SizedBox(height: 24),
                const Text(
                  'Color',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: _selectedType,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedType = value;
                      _selectedColor = _strainTypes[value]![0];
                    });
                  },
                  child: Column(
                    children: [
                      for (var type in _strainTypes.entries) ...[
                        Row(
                          children: [
                            Radio<String>(value: type.key),
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      final provider =
                          Provider.of<KratomProvider>(context, listen: false);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await provider.addStrain(
                          _nameController.text.trim(),
                          _codeController.text.trim(),
                          _selectedColor!.color.toARGB32(),
                          _selectedShape.name,
                          inStock: _inStock,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Could not save strain: $e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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
