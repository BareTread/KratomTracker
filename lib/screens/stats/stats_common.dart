import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Page chrome for stats: no cards, no boxes inside boxes. Sections are set
/// apart by a quiet label, generous air and a rule that fades at both ends —
/// the same device the home screen uses under its status line.
class StatsSection extends StatelessWidget {
  const StatsSection({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        const FadedRule(),
        const SizedBox(height: 18),
        Text(label, style: sectionLabelStyle(context)),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

TextStyle sectionLabelStyle(BuildContext context) => TextStyle(
      color: context.c.textTertiary,
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );

/// Quiet secondary line — the register the home screen's status line uses.
TextStyle quietStyle(BuildContext context) => TextStyle(
      color: context.c.textSecondary,
      fontSize: 13,
      height: 1.35,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class FadedRule extends StatelessWidget {
  const FadedRule({super.key});

  @override
  Widget build(BuildContext context) {
    final line = context.c.hairline;
    return SizedBox(
      width: double.infinity,
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              line.withValues(alpha: 0),
              line,
              line,
              line.withValues(alpha: 0),
            ],
            stops: const [0, 0.06, 0.94, 1],
          ),
        ),
      ),
    );
  }
}

/// One decimal, but never a trailing `.0` — `11g` reads faster than `11.0g`.
String formatAmount(double value) {
  if (!value.isFinite) return '0';
  final rounded = (value * 10).roundToDouble() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
  return rounded.toStringAsFixed(1);
}

/// A signed whole percent, or an em dash when there is no honest number.
String formatDelta(double? percent) {
  if (percent == null) return '—';
  final rounded = percent.abs().round();
  if (rounded == 0) return 'flat';
  return '${percent < 0 ? '−' : '+'}$rounded%';
}

/// Up is the direction worth noticing on a tolerance-managed habit, so it
/// takes the caution colour; down takes the calm one. Flat stays neutral —
/// steady is not an achievement to celebrate, just the normal state.
Color deltaColor(BuildContext context, double? percent, {double band = 8}) {
  final c = context.c;
  if (percent == null || percent.abs() < band) return c.textTertiary;
  return percent > 0 ? c.caution : c.positive;
}
