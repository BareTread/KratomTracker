import 'package:flutter/material.dart';

import '../domain/strain_usage.dart';
import '../theme/app_theme.dart';
import 'strain_mark.dart';

/// One row in the smart strain picker. Renders a [StrainUsage] without
/// re-sorting or filtering — callers iterate `provider.strainUsage` as-is.
///
/// When [inStock] is false the row is de-emphasised (reduced opacity on text)
/// but the strain colour swatch stays at full strength so the strain stays
/// identifiable, and a one-tap "Back in stock" affordance is shown. The row
/// remains fully selectable.
class StrainUsageTile extends StatelessWidget {
  final StrainUsage usage;
  final VoidCallback onTap;
  final bool inStock;
  final VoidCallback? onToggleStock;

  const StrainUsageTile({
    super.key,
    required this.usage,
    required this.onTap,
    this.inStock = true,
    this.onToggleStock,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final strain = usage.strain;
    final strainColor = Color(strain.color);
    final isTopPick = usage.rank < 3;
    final showName = strain.name.trim().isNotEmpty &&
        strain.name.trim().toLowerCase() != strain.code.trim().toLowerCase();

    final recency = _recencyLine(usage);
    final semantics = _semanticsLabel(
      code: strain.code,
      name: showName ? strain.name : null,
      recency: recency,
      isTopPick: isTopPick,
      inStock: inStock,
    );

    final contentOpacity = inStock ? 1.0 : 0.55;

    return Semantics(
      button: true,
      label: semantics,
      child: Material(
        color: isTopPick
            ? strainColor.withValues(alpha: 0.12)
            : c.surfaceSunken.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Stack(
              children: [
                // The month's load, underlining the recency line on the text
                // grid so it costs no height and reads as a measure of that
                // line rather than as a divider between rows. Scanning down the
                // list shows which strains the rotation is leaning on.
                if (usage.relativeLoad > 0)
                  Positioned(
                    left: 64,
                    right: 12,
                    bottom: 9,
                    height: 2,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: usage.relativeLoad.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: strainColor.withValues(
                            alpha: inStock ? 0.38 : 0.18,
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: strainColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: StrainMark(
                            shape: resolveLeafShape(strain.icon, strain.code),
                            color: strainColor,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Opacity(
                          opacity: contentOpacity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            strain.code,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: c.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (showName) ...[
                                          const SizedBox(width: 8),
                                          Flexible(
                                            flex: 2,
                                            child: Text(
                                              strain.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: c.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isTopPick) ...[
                                    const SizedBox(width: 8),
                                    _RotationPickMarker(color: strainColor),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                recency,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!inStock && onToggleStock != null) ...[
                        const SizedBox(width: 8),
                        _BackInStockButton(onTap: onToggleStock!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Rest, then load — the same two facts the ranking is built from, so the
  /// order of the list can be read off the rows instead of guessed at. The old
  /// line described the last day the strain was touched, which is an arbitrary
  /// snapshot and had nothing to do with where the row sat.
  static String _recencyLine(StrainUsage usage) {
    if (usage.lastUsed == null) return 'never used';

    final when = _whenLabel(usage.daysSinceLastUse);
    if (usage.grams30d <= 0) return '$when · none this month';
    return '$when · ${_formatGrams(usage.grams30d)}g in 30d';
  }

  static String _whenLabel(double daysSince) {
    final days = daysSince.floor();
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 30) return '${days}d ago';
    final months = (days / 30).floor();
    if (months < 12) return '${months}mo ago';
    final years = (days / 365).floor();
    return years <= 1 ? '1y ago' : '${years}y ago';
  }

  static String _formatGrams(double grams) {
    if (grams == grams.roundToDouble()) {
      return grams.toStringAsFixed(0);
    }
    final one = grams.toStringAsFixed(1);
    return one.endsWith('.0') ? one.substring(0, one.length - 2) : one;
  }

  static String _semanticsLabel({
    required String code,
    required String? name,
    required String recency,
    required bool isTopPick,
    required bool inStock,
  }) {
    final buffer = StringBuffer(code);
    if (name != null) buffer.write(', $name');
    buffer.write(', $recency');
    if (isTopPick) buffer.write(', rotation pick');
    buffer.write(inStock ? ', in stock' : ', out of stock');
    return buffer.toString();
  }
}

class _RotationPickMarker extends StatelessWidget {
  final Color color;

  const _RotationPickMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        'rotation',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          height: 1.1,
          color: color,
        ),
      ),
    );
  }
}

class _BackInStockButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackInStockButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: 'Back in stock',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 14, color: c.accent),
              const SizedBox(width: 4),
              Text(
                'Back in stock',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
