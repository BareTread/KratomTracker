import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/analytics_service.dart';
import '../domain/date_utils.dart';
import '../models/strain.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import 'report_screen.dart';

enum _Range { seven, thirty, ninety, all }

extension on _Range {
  String get label => switch (this) {
        _Range.seven => '7d',
        _Range.thirty => '30d',
        _Range.ninety => '90d',
        _Range.all => 'All',
      };

  int? get days => switch (this) {
        _Range.seven => 7,
        _Range.thirty => 30,
        _Range.ninety => 90,
        _Range.all => null,
      };
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Range _range = _Range.thirty;

  // Memoised bundle, recomputed only when provider data or the range changes.
  _StatsBundle? _bundle;
  ({_Range range, int stamp})? _bundleKey;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _SmoothScrollBehavior(),
      child: Consumer<KratomProvider>(
        builder: (context, provider, child) {
          final bundle = _resolveBundle(provider);
          final c = context.c;

          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).padding.top,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                pinned: true,
                elevation: 0,
                toolbarHeight: 0,
                collapsedHeight: 0,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stats',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _RangeSelector(
                        range: _range,
                        onChanged: (r) => setState(() => _range = r),
                      ),
                      const SizedBox(height: 16),
                      _HeadlineRow(bundle: bundle, range: _range),
                      const SizedBox(height: 16),
                      _DailyTrendSection(bundle: bundle, range: _range),
                      const SizedBox(height: 16),
                      _RhythmSection(bundle: bundle),
                      const SizedBox(height: 16),
                      _RotationHeatmapSection(bundle: bundle, range: _range),
                      const SizedBox(height: 16),
                      _RestDaysSection(bundle: bundle, range: _range),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
                      ListTile(
                        leading: Icon(Icons.history, color: c.accent),
                        title: const Text('Dosage History'),
                        subtitle: const Text(
                          'View detailed history of your doses',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReportScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  _StatsBundle _resolveBundle(KratomProvider provider) {
    final key = (range: _range, stamp: provider.lastMutationStamp);
    if (_bundle != null && _bundleKey == key) return _bundle!;
    final bundle = _StatsBundle.compute(provider, _range);
    _bundle = bundle;
    _bundleKey = key;
    return bundle;
  }
}

/// All numbers for the selected range, computed once per range/data change.
class _StatsBundle {
  final DoseStats current;
  final DoseStats? previous;
  final Map<DateTime, double> daily;
  final List<({DateTime day, double value})> rolling;
  final List<int> hours;
  final Map<String, Map<DateTime, double>> strainDaily;
  final List<Strain> heatmapStrains; // strains present in range, by total grams
  final Map<String, double> strainTotals;
  final DateTimeRange range;

  _StatsBundle({
    required this.current,
    required this.previous,
    required this.daily,
    required this.rolling,
    required this.hours,
    required this.strainDaily,
    required this.heatmapStrains,
    required this.strainTotals,
    required this.range,
  });

  factory _StatsBundle.compute(KratomProvider provider, _Range selected) {
    final now = DateTime.now();
    final dosages = provider.dosages;
    final strains = provider.strains;

    final DateTimeRange range;
    final DoseStats? previous;
    switch (selected) {
      case _Range.seven:
      case _Range.thirty:
      case _Range.ninety:
        final n = selected.days!;
        range = lastNDays(n, now: now);
        final prevRange = DateTimeRange(
          start: range.start.subtract(Duration(days: n)),
          end: range.start.subtract(const Duration(days: 1)),
        );
        previous = computeDoseStats(dosages, prevRange);
      case _Range.all:
        if (dosages.isEmpty) {
          range = lastNDays(1, now: now);
        } else {
          final earliest = dosages
              .map((d) => startOfDay(d.timestamp))
              .reduce((a, b) => a.isBefore(b) ? a : b);
          range = DateTimeRange(start: earliest, end: startOfDay(now));
        }
        previous = null;
    }

    final current = computeDoseStats(dosages, range);
    final daily = dailyTotals(dosages, range);
    final rolling = rollingAverage(daily, 7);
    final hours = hourHistogram(
      dosages
          .where((d) => inRangeInclusive(d.timestamp, range.start, range.end))
          .toList(growable: false),
    );
    final strainDaily = strainDailyTotals(dosages, range);

    final strainTotals = <String, double>{};
    for (final entry in strainDaily.entries) {
      strainTotals[entry.key] =
          entry.value.values.fold(0.0, (sum, g) => sum + g);
    }
    final heatmapStrains = strains
        .where((s) => strainTotals.containsKey(s.id))
        .toList()
      ..sort(
        (a, b) => (strainTotals[b.id] ?? 0).compareTo(strainTotals[a.id] ?? 0),
      );

    return _StatsBundle(
      current: current,
      previous: previous,
      daily: daily,
      rolling: rolling,
      hours: hours,
      strainDaily: strainDaily,
      heatmapStrains: heatmapStrains,
      strainTotals: strainTotals,
      range: range,
    );
  }
}

// ---------------------------------------------------------------------------
// Range selector
// ---------------------------------------------------------------------------

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.range, required this.onChanged});

  final _Range range;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_Range>(
      style: const ButtonStyle(
        visualDensity: VisualDensity(horizontal: -3, vertical: -2),
      ),
      segments: [
        for (final r in _Range.values) ButtonSegment(value: r, label: Text(r.label)),
      ],
      selected: {range},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ---------------------------------------------------------------------------
// Headline row
// ---------------------------------------------------------------------------

class _HeadlineRow extends StatelessWidget {
  const _HeadlineRow({required this.bundle, required this.range});

  final _StatsBundle bundle;
  final _Range range;

  @override
  Widget build(BuildContext context) {
    final cur = bundle.current;
    final prev = bundle.previous;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          label: 'Total',
          value: '${cur.totalGrams.toStringAsFixed(1)}g',
          delta: _delta(cur.totalGrams, prev?.totalGrams, range, 'g'),
        ),
        _StatCard(
          label: 'Doses',
          value: '${cur.totalDoses}',
          delta: _delta(
            cur.totalDoses.toDouble(),
            prev?.totalDoses.toDouble(),
            range,
            '',
          ),
        ),
        _StatCard(
          label: 'Daily avg',
          value: '${cur.avgPerDay.toStringAsFixed(1)}g',
          delta: _delta(cur.avgPerDay, prev?.avgPerDay, range, 'g'),
        ),
        _StatCard(
          label: 'Avg dose',
          value: '${cur.avgDoseSize.toStringAsFixed(1)}g',
          delta: _delta(cur.avgDoseSize, prev?.avgDoseSize, range, 'g'),
        ),
      ],
    );
  }
}

String _delta(
  double current,
  double? previous,
  _Range range,
  String unit,
) {
  if (previous == null) return '';
  if (previous == 0) {
    return current > 0 ? 'new vs previous ${range.label}' : '— vs previous ${range.label}';
  }
  final pct = ((current - previous) / previous) * 100;
  final sign = pct >= 0 ? '+' : '−';
  return '$sign${pct.abs().toStringAsFixed(0)}% vs previous ${range.label}';
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: (MediaQuery.sizeOf(context).width - 16 * 2 - 12) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
          ),
          if (delta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              delta,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textTertiary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily trend (area + rolling line)
// ---------------------------------------------------------------------------

class _DailyTrendSection extends StatelessWidget {
  const _DailyTrendSection({required this.bundle, required this.range});

  final _StatsBundle bundle;
  final _Range range;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = bundle.daily.keys.toList()..sort();
    final hasData = bundle.current.totalDoses > 0;

    return _Section(
      icon: Icons.show_chart,
      title: 'Daily trend',
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 180,
                  child: Semantics(
                    container: true,
                    label: 'Daily grams trend chart for the last '
                        '${range.label} with a 7-day rolling average line.',
                    child: _DailyTrendChart(bundle: bundle, days: days),
                  ),
                ),
                const SizedBox(height: 8),
                _ChartLegend(
                  items: [
                    (color: c.accent, label: 'Daily grams'),
                    (color: c.caution, label: '7-day rolling average'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _trendSummary(bundle, days),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
              ],
            )
          : const _EmptyState(
              icon: Icons.show_chart,
              message: 'No doses in this range yet.',
            ),
    );
  }
}

String _trendSummary(_StatsBundle bundle, List<DateTime> days) {
  final maxDay = days.reduce((a, b) {
    final av = bundle.daily[a] ?? 0;
    final bv = bundle.daily[b] ?? 0;
    return av >= bv ? a : b;
  });
  final maxGrams = bundle.daily[maxDay] ?? 0;
  final peakRolling = bundle.rolling.reduce(
    (a, b) => a.value >= b.value ? a : b,
  );
  return 'Peak day: ${DateFormat('MMM d').format(maxDay)} at '
      '${maxGrams.toStringAsFixed(1)}g; 7-day avg peaked at '
      '${peakRolling.value.toStringAsFixed(1)}g/day ending '
      '${DateFormat('MMM d').format(peakRolling.day)}.';
}

class _DailyTrendChart extends StatelessWidget {
  const _DailyTrendChart({required this.bundle, required this.days});

  final _StatsBundle bundle;
  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = days.length;
    final dailySpots = [
      for (var i = 0; i < n; i++)
        FlSpot(i.toDouble(), bundle.daily[days[i]] ?? 0),
    ];
    final rollingSpots = [
      for (var i = 0; i < bundle.rolling.length; i++)
        FlSpot(i.toDouble(), bundle.rolling[i].value),
    ];
    final maxY = math.max(
      dailySpots.fold<double>(0, (m, s) => math.max(m, s.y)),
      rollingSpots.fold<double>(0, (m, s) => math.max(m, s.y)),
    );
    final topY = maxY <= 0 ? 1.0 : maxY * 1.15;
    final interval = topY / 4;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: c.hairline, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              reservedSize: 34,
              getTitlesWidget: (value, meta) => Text(
                _formatGrams(value),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      color: c.textTertiary,
                    ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: 0,
        maxY: topY,
        lineBarsData: [
          LineChartBarData(
            spots: dailySpots,
            isCurved: false,
            color: c.accent.withValues(alpha: 0.45),
            barWidth: 1,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            dashArray: [3, 3],
            belowBarData: BarAreaData(
              show: true,
              color: c.accent.withValues(alpha: 0.08),
            ),
          ),
          LineChartBarData(
            spots: rollingSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: c.caution,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rhythm
// ---------------------------------------------------------------------------

class _RhythmSection extends StatelessWidget {
  const _RhythmSection({required this.bundle});

  final _StatsBundle bundle;

  @override
  Widget build(BuildContext context) {
    final stats = bundle.current;
    final hasData = stats.totalDoses > 0;
    final peakHour = stats.peakHour;
    final gap = stats.avgGapBetweenDoses;

    return _Section(
      icon: Icons.schedule,
      title: 'Rhythm',
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 140,
                  child: Semantics(
                    container: true,
                    label: '24-hour histogram of when your doses happen. '
                        'Peak hour: ${peakHour != null ? DateFormat('h a').format(DateTime(2024, 1, 1, peakHour)) : 'none'}.',
                    child: _HourHistogramChart(hours: bundle.hours),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _Fact(
                      label: 'Peak hour',
                      value: peakHour != null
                          ? DateFormat('h a').format(
                              DateTime(2024, 1, 1, peakHour),
                            )
                          : '—',
                    ),
                    _Fact(
                      label: 'Avg gap between doses',
                      value: gap != null ? _formatDuration(gap) : '—',
                    ),
                  ],
                ),
              ],
            )
          : const _EmptyState(
              icon: Icons.schedule,
              message: 'No doses in this range yet.',
            ),
    );
  }
}

class _HourHistogramChart extends StatelessWidget {
  const _HourHistogramChart({required this.hours});

  final List<int> hours;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final maxCount = hours.fold<int>(0, (m, v) => math.max(m, v));
    final topY = maxCount <= 0 ? 1.0 : maxCount.toDouble();

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 6,
              reservedSize: 18,
              getTitlesWidget: (value, meta) => Text(
                _hourLabel(value.round()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      color: c.textTertiary,
                    ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        maxY: topY * 1.1,
        barGroups: [
          for (var h = 0; h < 24; h++)
            BarChartGroupData(
              x: h,
              barRods: [
                BarChartRodData(
                  toY: hours[h].toDouble(),
                  width: 6,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                  color: c.accent.withValues(
                    alpha: hours[h] == 0 ? 0.12 : 0.85,
                  ),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(enabled: false),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rotation heatmap
// ---------------------------------------------------------------------------

class _RotationHeatmapSection extends StatelessWidget {
  const _RotationHeatmapSection({required this.bundle, required this.range});

  final _StatsBundle bundle;
  final _Range range;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final strains = bundle.heatmapStrains;
    final days = bundle.daily.keys.toList()..sort();
    final hasData = strains.isNotEmpty;

    return _Section(
      icon: Icons.grid_view,
      title: 'Rotation heatmap',
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Each cell is one day for one strain; opacity scales with '
                  'grams that day in the strain\'s own colour. Clustering on '
                  'a single strain shows up as a solid run of cells.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  container: true,
                  label: 'Rotation heatmap with ${_plural(strains.length, 'strain')} '
                      'across ${_plural(days.length, 'day')}.',
                  child: _RotationHeatmap(
                    bundle: bundle,
                    strains: strains,
                    days: days,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _heatmapSummary(bundle, strains, days),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
              ],
            )
          : const _EmptyState(
              icon: Icons.grid_view,
              message: 'No strain usage in this range yet.',
            ),
    );
  }
}

String _heatmapSummary(
  _StatsBundle bundle,
  List<Strain> strains,
  List<DateTime> days,
) {
  if (strains.isEmpty) return '';
  final top = strains.first;
  final topGrams = bundle.strainTotals[top.id] ?? 0;
  final share = bundle.current.totalGrams > 0
      ? (topGrams / bundle.current.totalGrams * 100).toStringAsFixed(0)
      : '0';
  return '${_plural(strains.length, 'strain')} across '
      '${_plural(days.length, 'day')}; most used ${top.code} at '
      '${topGrams.toStringAsFixed(1)}g ($share%).';
}

class _RotationHeatmap extends StatelessWidget {
  const _RotationHeatmap({
    required this.bundle,
    required this.strains,
    required this.days,
  });

  final _StatsBundle bundle;
  final List<Strain> strains;
  final List<DateTime> days;

  static const _cellSize = 16.0;
  static const _labelWidth = 84.0;
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: day labels every 7 days.
          Row(
            children: [
              const SizedBox(width: _labelWidth + _gap),
              for (var i = 0; i < days.length; i++)
                if (i % 7 == 0)
                  Padding(
                    padding: const EdgeInsets.only(right: _gap),
                    child: SizedBox(
                      width: _cellSize,
                      child: Text(
                        DateFormat('d').format(days[i]),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              color: c.textTertiary,
                            ),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: _gap),
                    child: SizedBox(width: _cellSize),
                  ),
            ],
          ),
          for (final strain in strains) _heatRow(context, strain),
        ],
      ),
    );
  }

  Widget _heatRow(BuildContext context, Strain strain) {
    final perDay = bundle.strainDaily[strain.id] ?? const {};
    final maxGrams = perDay.values.fold<double>(0, (m, g) => math.max(m, g));
    return Padding(
      padding: const EdgeInsets.only(bottom: _gap),
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            height: _cellSize,
            child: Text(
              strain.code,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    height: 1.0,
                    color: legibleStrainColor(
                      Color(strain.color),
                      Theme.of(context).brightness,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: _gap),
          for (var i = 0; i < days.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: _cell(context, strain, perDay[days[i]] ?? 0, maxGrams),
            ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    Strain strain,
    double grams,
    double maxGrams,
  ) {
    final c = context.c;
    final alpha = maxGrams <= 0 ? 0.0 : (grams / maxGrams).clamp(0.0, 1.0);
    return Container(
      width: _cellSize,
      height: _cellSize,
      decoration: BoxDecoration(
        color: grams <= 0
            ? c.surfaceSunken
            : Color(strain.color).withValues(alpha: 0.2 + alpha * 0.8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rest days
// ---------------------------------------------------------------------------

class _RestDaysSection extends StatelessWidget {
  const _RestDaysSection({required this.bundle, required this.range});

  final _StatsBundle bundle;
  final _Range range;

  @override
  Widget build(BuildContext context) {
    final stats = bundle.current;
    final totalDays = stats.activeDays + stats.restDays;

    return _Section(
      icon: Icons.nights_stay_outlined,
      title: 'Rest days',
      child: totalDays == 0
          ? const _EmptyState(
              icon: Icons.nights_stay_outlined,
              message: 'No days in this range yet.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _Fact(
                      label: 'Active days',
                      value: '${stats.activeDays} of $totalDays',
                    ),
                    _Fact(
                      label: 'Zero-dose days',
                      value: '${stats.restDays}',
                    ),
                    _Fact(
                      label: 'Current streak',
                      value: _plural(stats.currentStreakDays, 'day'),
                    ),
                    _Fact(
                      label: 'Longest rest streak',
                      value: _plural(stats.longestRestStreak, 'day'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.textTertiary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items});

  final List<({Color color, String label})> items;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(
      spacing: 16,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: c.textTertiary),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textTertiary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _plural(int n, String unit) => n == 1 ? '1 $unit' : '$n ${unit}s';

String _hourLabel(int hour) {
  final h = hour % 24;
  final am = h < 12;
  final display = h % 12 == 0 ? 12 : h % 12;
  return '$display${am ? 'a' : 'p'}';
}

String _formatGrams(double v) {
  if (v == v.roundToDouble()) return '${v.round()}g';
  return '${v.toStringAsFixed(1)}g';
}

String _formatDuration(Duration d) {
  if (d.inHours >= 1) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
  return '${d.inMinutes}m';
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();
}
