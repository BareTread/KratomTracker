import 'dart:collection';

import 'package:flutter/material.dart';

const Map<String, IconData> strainIcons = {
  'Leaf': Icons.eco_outlined,
  'Plant': Icons.local_florist_outlined,
  'Natural': Icons.grass_outlined,
  'Organic': Icons.spa_outlined,
  'Flower': Icons.local_florist,
  'Herb': Icons.eco,
  'Forest': Icons.forest_outlined,
  'Nature': Icons.nature_outlined,
  'Park': Icons.park_outlined,
  'Yard': Icons.yard_outlined,
};

// CROSS-PACKAGE REQUEST: Form owners should build their pickers from
// strainIcons so add/edit flows persist the same icon name-to-glyph mapping.
final List<Map<String, Object>> iconOptions = UnmodifiableListView(
  strainIcons.entries
      .map((entry) => {'name': entry.key, 'icon': entry.value})
      .toList(growable: false),
);
