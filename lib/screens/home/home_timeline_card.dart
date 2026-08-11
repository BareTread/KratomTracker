import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/dosage.dart';
import '../../models/strain.dart';
import '../../theme/app_theme.dart';
import '../../widgets/timeline_painter.dart';

class HomeTimelineCard extends StatelessWidget {
  const HomeTimelineCard({
    super.key,
    required this.dosages,
    required this.strainsById,
  });

  final List<Dosage> dosages;
  final Map<String, Strain> strainsById;

  @override
  Widget build(BuildContext context) {
    final total = dosages.fold<double>(0, (sum, dose) => sum + dose.amount);
    final heights = _calculateHeights(dosages);
    final timeline = [
      for (final dose in dosages)
        (
          timestamp: dose.timestamp,
          amount: dose.amount,
          color: strainsById[dose.strainId] == null
              ? context.c.textTertiary
              : Color(strainsById[dose.strainId]!.color),
          height: heights[dose.id] ?? 0,
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Timeline',
                style: TextStyle(
                  color: context.c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.c.surfaceSunken,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _CountingTotal(value: total),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomPaint(
              size: const Size(double.infinity, 46),
              painter: TimelinePainter(
                backgroundColor: context.c.surfaceSunken,
                bandColor: context.c.surfaceRaised,
                dividerColor: context.c.hairline,
                labelColor: context.c.textTertiary,
                dosages: timeline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, double> _calculateHeights(List<Dosage> values) {
    if (values.isEmpty) return const {};
    if (values.length == 1) return {values.single.id: 24};
    final maximum = values.map((d) => d.amount).reduce(max);
    final minimum = values.map((d) => d.amount).reduce(min);
    final range = maximum - minimum;
    final ratio = maximum / minimum;
    return {
      for (final dose in values)
        dose.id: range == 0
            ? 22
            : 12 +
                20 *
                    (ratio > 5
                        ? log(dose.amount / minimum) / log(ratio)
                        : (dose.amount - minimum) / range),
    };
  }
}

class _CountingTotal extends StatefulWidget {
  const _CountingTotal({required this.value});

  final double value;

  @override
  State<_CountingTotal> createState() => _CountingTotalState();
}

class _CountingTotalState extends State<_CountingTotal> {
  double _from = 0;

  @override
  void didUpdateWidget(covariant _CountingTotal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _from = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.value),
      duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.normal,
      curve: AppMotion.emphasized,
      builder: (_, value, __) => Text(
        '${value.toStringAsFixed(1)}g',
        style: TextStyle(
          color: context.c.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
