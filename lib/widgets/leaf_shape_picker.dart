import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'strain_mark.dart';

/// Compact picker for a strain's [LeafShape]. Renders all ten ribbed-stroke
/// marks at real size in the strain's currently selected colour, so what is
/// picked is what will be seen on the tile. Shapes already taken for that
/// colour by another strain are marked, and the currently selected pair is
/// highlighted.
///
/// It sits inside an existing form, so it stays small: a wrapping row of
/// 48x48 tiles. The collision warning that names the owning strain lives in
/// the form, not here.
class LeafShapePicker extends StatelessWidget {
  const LeafShapePicker({
    super.key,
    required this.selectedShape,
    required this.color,
    required this.takenShapes,
    this.onChanged,
  });

  final LeafShape selectedShape;
  final Color color;

  /// Shapes already owned by another strain for [color]. Marked with a dot so
  /// the owner can see at a glance which pairs are free.
  final Set<LeafShape> takenShapes;
  final ValueChanged<LeafShape>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final shape in LeafShape.values)
          _ShapeTile(
            shape: shape,
            color: color,
            selected: shape == selectedShape,
            taken: takenShapes.contains(shape),
            onTap: onChanged == null ? null : () => onChanged!(shape),
          ),
      ],
    );
  }
}

class _ShapeTile extends StatelessWidget {
  const _ShapeTile({
    required this.shape,
    required this.color,
    required this.selected,
    required this.taken,
    required this.onTap,
  });

  final LeafShape shape;
  final Color color;
  final bool selected;
  final bool taken;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final markColor = selected ? color : c.textTertiary;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${shape.label}${taken ? ', already in use' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.16) : c.surfaceSunken,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : c.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Opacity(
                  opacity: selected ? 1 : 0.7,
                  child: StrainMark(shape: shape, color: markColor, size: 26),
                ),
              ),
              if (taken)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
