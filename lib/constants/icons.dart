import 'package:flutter/material.dart';

/// Legacy Material icon name → glyph map.
///
/// Retained only for `lib/screens/home/home_dosage_list.dart`, which another
/// worker is redesigning concurrently. Everything else now renders through
/// `StrainMark` / `LeafMarkPainter` and stores a `LeafShape.name`. The home
/// dose rows will be rewired to the shared mark widget after both branches
/// merge — see the CROSS-PACKAGE REQUEST in the adopting task's report.
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
