import 'package:flutter/material.dart';

import '../domain/strain_usage.dart';
import '../theme/app_theme.dart';
import 'strain_mark.dart';

/// One row in the smart strain picker. Renders a [StrainUsage] without
/// re-sorting or filtering — callers iterate `provider.strainUsage` as-is.
///
/// When [inStock] is false the row is de-emphasised (reduced opacity on text
/// and the freshness bar) but the strain colour swatch stays at full strength
/// so the strain stays identifiable, and a one-tap "Back in stock" affordance
/// is shown. The row remains fully selectable.
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
    final load = _loadLine(usage);
    final semantics = _semanticsLabel(
      code: strain.code,
      name: showName ? strain.name : null,
      recency: recency,
      load: load,
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
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      strain.code,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isTopPick) ...[
                                    const SizedBox(width: 8),
                                    _RotationPickMarker(color: strainColor),
                                  ],
                                ],
                              ),
                              if (showName) ...[
                                const SizedBox(height: 2),
                                Text(
                                  strain.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                recency,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.25,
                                  color: c.textSecondary,
                                ),
                              ),
                              if (load != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  load,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.textTertiary,
                                  ),
                                ),
                              ],
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
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: contentOpacity,
                    child: _FreshnessBar(
                      daysSinceLastUse: usage.daysSinceLastUse,
                      neverUsed: usage.lastUsed == null,
                      color: strainColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _recencyLine(StrainUsage usage) {
    if (usage.lastUsed == null) return 'never used';

    final when = _whenLabel(usage.daysSinceLastUse);
    final grams = _formatGrams(usage.gramsLastUsedDay);

    if (usage.dosesLastUsedDay > 1) {
      return '$when · ${usage.dosesLastUsedDay} doses that day · ${grams}g';
    }
    return '$when · 1 dose · ${grams}g';
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

  static String? _loadLine(StrainUsage usage) {
    final parts = <String>[];
    if (usage.grams7d > 0) {
      parts.add('7d ${_formatGrams(usage.grams7d)}g');
    }
    if (usage.grams30d > 0) {
      parts.add('30d ${_formatGrams(usage.grams30d)}g');
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
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
    required String? load,
    required bool isTopPick,
    required bool inStock,
  }) {
    final buffer = StringBuffer(code);
    if (name != null) buffer.write(', $name');
    buffer.write(', $recency');
    if (load != null) buffer.write(', $load');
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

class _FreshnessBar extends StatelessWidget {
  final double daysSinceLastUse;
  final bool neverUsed;
  final Color color;

  const _FreshnessBar({
    required this.daysSinceLastUse,
    required this.neverUsed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fill = neverUsed
        ? 1.0
        : (daysSinceLastUse / 14.0).clamp(0.0, 1.0);
    final alpha = neverUsed ? 0.28 : 0.85;

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: color.withValues(alpha: 0.12)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill,
              child: ColoredBox(color: color.withValues(alpha: alpha)),
            ),
          ],
        ),
      ),
    );
  }
}
