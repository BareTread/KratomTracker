import 'package:flutter/material.dart';

import '../../domain/analytics_service.dart';
import '../../theme/app_theme.dart';
import 'stats_bundle.dart';
import 'stats_common.dart';

/// The one line the page exists to say. Everything below it is evidence.
String driftHeadline(DriftReading drift, StatsRange range) {
  final level = formatAmount(drift.level.gramsPerDay);
  final percent = drift.changePercent;
  return switch (drift.direction) {
    DriftDirection.unknown => 'Not enough history yet',
    DriftDirection.steady => 'Holding steady around ${level}g/day',
    DriftDirection.up => percent == null
        ? 'Drifting up ${range.phrase}'
        : 'Up ${percent.round()}% ${range.phrase}',
    DriftDirection.down => percent == null
        ? 'Drifting down ${range.phrase}'
        : 'Down ${percent.abs().round()}% ${range.phrase}',
  };
}

/// The actionable half: *how* it moved. More doses and bigger doses are
/// different problems with different fixes, and the total alone hides which
/// one is happening.
String? driftDetail(DriftReading drift) {
  final up = drift.direction == DriftDirection.up;
  switch (drift.driver) {
    case IntakeDriver.frequency:
      return up ? 'More doses, not bigger ones.' : 'Fewer doses, same size.';
    case IntakeDriver.size:
      return up
          ? 'Bigger doses, not more of them.'
          : 'Smaller doses, same number of them.';
    case IntakeDriver.both:
      return up
          ? 'More doses and bigger ones.'
          : 'Fewer doses and smaller ones.';
    case IntakeDriver.none:
      if (drift.direction == DriftDirection.unknown && drift.level.doses > 0) {
        return 'Around ${formatAmount(drift.level.gramsPerDay)}g/day so far.';
      }
      return null;
  }
}

class StatsHeadline extends StatelessWidget {
  const StatsHeadline({super.key, required this.bundle});

  final StatsBundle bundle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final drift = bundle.drift;
    final detail = driftDetail(drift);
    final Color color = switch (drift.direction) {
      DriftDirection.up => c.caution,
      DriftDirection.down => c.positive,
      _ => c.textPrimary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          driftHeadline(drift, bundle.selected),
          style: TextStyle(
            color: color,
            fontSize: 21,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 6),
          Text(detail, style: quietStyle(context)),
        ],
      ],
    );
  }
}

/// `G = F × A` laid out as the equation it is: daily grams, then the two
/// factors that produce it. Reading the deltas across the row answers "how
/// did intake move" in one glance.
class IntakeEquation extends StatelessWidget {
  const IntakeEquation({super.key, required this.drift});

  final DriftReading drift;

  @override
  Widget build(BuildContext context) {
    final level = drift.level;
    final showDeltas = drift.direction != DriftDirection.unknown;

    return Semantics(
      container: true,
      label: '${formatAmount(level.gramsPerDay)} grams a day is '
          '${formatAmount(level.dosesPerDay)} doses a day at '
          '${formatAmount(level.gramsPerDose)} grams each.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Factor(
              value: formatAmount(level.gramsPerDay),
              unit: 'grams a day',
              delta: showDeltas ? drift.changePercent : null,
              showDelta: showDeltas,
            ),
          ),
          const _Operator('='),
          Expanded(
            child: _Factor(
              value: formatAmount(level.dosesPerDay),
              unit: 'doses a day',
              delta: showDeltas ? drift.dosesChangePercent : null,
              showDelta: showDeltas,
            ),
          ),
          const _Operator('×'),
          Expanded(
            child: _Factor(
              value: formatAmount(level.gramsPerDose),
              unit: 'grams a dose',
              delta: showDeltas ? drift.sizeChangePercent : null,
              showDelta: showDeltas,
            ),
          ),
        ],
      ),
    );
  }
}

class _Factor extends StatelessWidget {
  const _Factor({
    required this.value,
    required this.unit,
    required this.delta,
    required this.showDelta,
  });

  final String value;
  final String unit;
  final double? delta;
  final bool showDelta;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          maxLines: 1,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 25,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          unit,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.textTertiary, fontSize: 11, height: 1.2),
        ),
        if (showDelta) ...[
          const SizedBox(height: 7),
          Text(
            formatDelta(delta),
            maxLines: 1,
            style: TextStyle(
              color: deltaColor(context, delta),
              fontSize: 12.5,
              height: 1.1,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _Operator extends StatelessWidget {
  const _Operator(this.glyph);

  final String glyph;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Sits on the numbers' optical centre rather than their top edge.
      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
      child: Text(
        glyph,
        style: TextStyle(
          color: context.c.textTertiary,
          fontSize: 15,
          height: 1.1,
        ),
      ),
    );
  }
}
