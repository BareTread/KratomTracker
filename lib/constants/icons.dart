import 'package:flutter/material.dart';

// Define available strain icons
final Map<String, IconData> strainIcons = {
  'Leaf': Icons.eco_outlined,
  'Plant': Icons.local_florist_outlined,
  'Natural': Icons.grass_outlined,
  'Organic': Icons.spa_outlined,
  'Flower': Icons.local_florist,
  'Herb': Icons.eco,
};

// Define icon options for forms
final List<Map<String, dynamic>> iconOptions = [
  {'name': 'Leaf', 'icon': Icons.eco_outlined},
  {'name': 'Plant', 'icon': Icons.local_florist_outlined},
  {'name': 'Natural', 'icon': Icons.grass_outlined},
  {'name': 'Organic', 'icon': Icons.spa_outlined},
  {'name': 'Flower', 'icon': Icons.local_florist},
  {'name': 'Herb', 'icon': Icons.eco},
]; 