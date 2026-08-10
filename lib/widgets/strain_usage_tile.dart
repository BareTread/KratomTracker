import 'package:flutter/material.dart';

import '../constants/icons.dart';
import '../domain/strain_usage.dart';
import '../theme/app_theme.dart';

/// One row in the smart strain picker. Renders a [StrainUsage] without
/// re-sorting or filtering — callers iterate `provider.strainUsage` as-is.
class StrainUsageTile extends StatelessWidget {
  final StrainUsage usage;
  final VoidCallback onTap;

  const StrainUsageTile({
    super.key,
    required this.usage,
    required this.onTap,
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
    );

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
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: strainColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          strainIcons[strain.icon] ?? Icons.local_florist,
                          color: strainColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  _FreshnessBar(
                    daysSinceLastUse: usage.daysSinceLastUse,
                    neverUsed: usage.lastUsed == null,
                    color: strainColor,
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
    return '$when · ${grams}g';
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
  }) {
    final buffer = StringBuffer(code);
    if (name != null) buffer.write(', $name');
    buffer.write(', $recency');
    if (load != null) buffer.write(', $load');
    if (isTopPick) buffer.write(', rotation pick');
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
