import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dosage.dart';
import '../../providers/kratom_provider.dart';
import '../../theme/app_theme.dart';

class HomeDaySummary extends StatelessWidget {
  const HomeDaySummary({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    context.select<KratomProvider, int>(
      (provider) => Object.hashAll(provider.dosages),
    );
    final provider = context.read<KratomProvider>();
    final dosages = provider.dosages;
    // "Last dose" and the weekly total are current-moment facts about today.
    // When the owner scrolls back to a past day they describe a different day
    // than the timeline below, so hide them to keep one frame of reference.
    final isToday =
        DateUtils.dateOnly(date) == DateUtils.dateOnly(DateTime.now());
    if (!isToday) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dosages.isNotEmpty) _LastDoseCard(dosages: dosages),
        _WeeklySparkline(provider: provider),
      ],
    );
  }
}

class _LastDoseCard extends StatelessWidget {
  const _LastDoseCard({required this.dosages});

  final List<Dosage> dosages;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<KratomProvider>();
    final last = dosages.reduce(
      (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
    );
    final elapsed = DateTime.now().difference(last.timestamp);
    final strain = provider.getStrain(last.strainId);
    if (strain == null) return const SizedBox.shrink();

    final String elapsedText;
    final IconData icon;
    final Color statusColor;
    if (elapsed.inDays > 0) {
      elapsedText = '${elapsed.inDays}d ${elapsed.inHours % 24}h ago';
      icon = Icons.history;
      statusColor = context.c.textSecondary;
    } else if (elapsed.inHours >= 4) {
      elapsedText = '${elapsed.inHours}h ${elapsed.inMinutes % 60}m ago';
      icon = Icons.check_circle_outline;
      statusColor = context.c.positive;
    } else if (elapsed.inHours >= 2) {
      elapsedText = '${elapsed.inHours}h ${elapsed.inMinutes % 60}m ago';
      icon = Icons.schedule;
      statusColor = context.c.caution;
    } else {
      elapsedText =
          elapsed.inMinutes < 1 ? 'Just now' : '${elapsed.inMinutes}m ago';
      icon = Icons.access_time;
      statusColor = context.c.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.c.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last dose',
                  style: TextStyle(color: context.c.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  '$elapsedText · ${strain.code}',
                  style: TextStyle(
                    color: context.c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Color(strain.color).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${last.amount}g',
              style: TextStyle(
                color: Color(strain.color),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySparkline extends StatelessWidget {
  const _WeeklySparkline({required this.provider});

  final KratomProvider provider;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final week = List.generate(
      7,
      (i) => provider.totalForDate(today.subtract(Duration(days: 6 - i))),
    );
    final previous = List.generate(
      7,
      (i) => provider.totalForDate(today.subtract(Duration(days: 13 - i))),
    );
    final total = week.fold<double>(0, (a, b) => a + b);
    final previousTotal = previous.fold<double>(0, (a, b) => a + b);
    final change = previousTotal == 0
        ? 0.0
        : (total - previousTotal) / previousTotal * 100;
    final rising = change > 10;
    final falling = change < -10;
    final trendColor = rising
        ? context.c.caution
        : falling
            ? context.c.positive
            : context.c.textSecondary;
    final trendLabel = rising
        ? 'higher'
        : falling
            ? 'lower'
            : 'steady';
    final maximum = week.fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.c.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.show_chart, color: context.c.textTertiary, size: 18),
          const SizedBox(width: 10),
          Text(
            '${total.toStringAsFixed(1)}g',
            style: TextStyle(
              color: context.c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text('this week', style: TextStyle(color: context.c.textTertiary)),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 24,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: maximum > 0 ? maximum * 1.2 : 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < week.length; i++)
                          FlSpot(i.toDouble(), week[i]),
                      ],
                      isCurved: true,
                      color: context.c.accent,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: context.c.accent.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: const LineTouchData(enabled: false),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label:
                '${change.abs().toStringAsFixed(0)} percent $trendLabel than last week',
            child: Row(
              children: [
                Icon(
                  rising
                      ? Icons.trending_up
                      : falling
                          ? Icons.trending_down
                          : Icons.trending_flat,
                  size: 14,
                  color: trendColor,
                ),
                const SizedBox(width: 3),
                Text(
                  '${change.abs().toStringAsFixed(0)}%',
                  style:
                      TextStyle(color: trendColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
