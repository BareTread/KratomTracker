import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/date_utils.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import 'report_screen.dart';
import 'stats/stats_bundle.dart';
import 'stats/stats_common.dart';
import 'stats/stats_headline.dart';
import 'stats/stats_herbarium.dart';
import 'stats/stats_insights.dart';
import 'stats/stats_rest.dart';
import 'stats/stats_rotation.dart';
import 'stats/stats_totals.dart';
import 'stats/stats_trajectory.dart';
import 'stats/stats_when.dart';

/// One page, one question at a time, top to bottom:
///
///   * a sentence saying which way intake is going — the reason to open this
///     tab at all;
///   * `G = F × A`, so a rise says whether it came from more doses or bigger
///     ones, which are different problems;
///   * the trajectory, as evidence for the sentence;
///   * when the doses land, how the rotation is spread;
///   * an insight tier — the handful of things eighteen months of timestamps
///     can say that a total cannot, each silent until it has the observations
///     to back it;
///   * then the plain numbers: totals for the range, rest, and all time.
///
/// The order is deliberate. Everything above the fold argues a case; the
/// totals sit underneath as the material it was argued from, for when the
/// question is simply "how much".
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with WidgetsBindingObserver {
  StatsRange _range = StatsRange.thirty;

  // Memoised bundle, recomputed only when provider data, the range, or the
  // calendar day changes. Without the day, an overnight session keeps
  // yesterday's 30d/90d windows until a dose is logged or the range moves.
  StatsBundle? _bundle;
  ({StatsRange range, int stamp, DateTime day})? _bundleKey;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armMidnightTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _armMidnightTimer();
    }
  }

  void _armMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final next = addDays(startOfDay(now), 1);
    _midnightTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _armMidnightTimer();
    });
  }

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
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Same head the other tabs carry: serif screen title,
                      // with the range switch riding its row.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Stats',
                            style: AppType.display(
                              size: 36,
                              color: c.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          _RangePicker(
                            range: _range,
                            onChanged: (range) =>
                                setState(() => _range = range),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      ..._body(bundle),
                      // No history, nothing to report: the link only exists
                      // once there is a history to show.
                      if (bundle.hasHistory) ...[
                        const SizedBox(height: 26),
                        const FadedRule(),
                        const _HistoryLink(),
                      ],
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 32,
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

  List<Widget> _body(StatsBundle bundle) {
    if (!bundle.hasHistory) {
      return const [_NothingYet()];
    }
    final insights = InsightsSection(
      gap: bundle.gapCompression,
      cycle: bundle.returnCycle,
      breadth: bundle.breadth,
      firstDose: bundle.firstDoseDrift,
    );
    return [
      StatsHeadline(bundle: bundle),
      if (bundle.hasDataInRange) ...[
        const SizedBox(height: 20),
        IntakeEquation(drift: bundle.drift),
        const SizedBox(height: 28),
        // 30 days fit as a page of pressed sprigs, one a day; 90d and All
        // would be thirteen-plus rows of them, so they keep the bar chart.
        if (bundle.selected == StatsRange.thirty)
          StatsHerbarium(bundle: bundle)
        else
          TrajectoryChart(bundle: bundle),
        StatsSection(
          label: 'When',
          child: WhenSection(rhythm: bundle.rhythm),
        ),
        StatsSection(
          label: 'Rotation',
          child: RotationSection(
            rotation: bundle.rotation,
            strainsById: bundle.strainsById,
          ),
        ),
        if (insights.hasAny) StatsSection(label: 'Insights', child: insights),
        StatsSection(
          label: 'Totals',
          child: TotalsSection(
            range: bundle.rangeFactors,
            active: bundle.activeFactors,
            spacing: bundle.spacing,
            weekday: bundle.weekday,
          ),
        ),
      ],
      StatsSection(label: 'Rest', child: RestLine(stats: bundle.stats)),
      StatsSection(
        label: 'All time',
        child: AllTimeSection(totals: bundle.totals),
      ),
    ];
  }

  StatsBundle _resolveBundle(KratomProvider provider) {
    final key = (
      range: _range,
      stamp: provider.lastMutationStamp,
      day: startOfDay(DateTime.now()),
    );
    if (_bundle != null && _bundleKey == key) return _bundle!;
    final bundle = StatsBundle.compute(provider, _range);
    _bundle = bundle;
    _bundleKey = key;
    return bundle;
  }
}

/// Three words, one of them lit. A segmented control would put a box and two
/// borders at the top of a page whose whole argument is that typography can
/// carry it. Each option still owns a real 48dp tap target; the selection
/// mark is a short accent rule under the lit word.
class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.range, required this.onChanged});

  final StatsRange range;
  final ValueChanged<StatsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in StatsRange.values)
          InkWell(
            onTap: () => onChanged(option),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      color:
                          option == range ? c.textPrimary : c.textSecondary,
                      fontSize: 13.5,
                      height: 1.1,
                      fontWeight: option == range
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 16,
                    height: 2,
                    decoration: BoxDecoration(
                      color:
                          option == range ? c.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nothing logged yet',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 21,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'After a few days of doses this page shows your daily trend, '
          'when you dose, and how your strains rotate. '
          'Log doses from Home with the + button.',
          style: quietStyle(context),
        ),
      ],
    );
  }
}

class _HistoryLink extends StatelessWidget {
  const _HistoryLink();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      key: const Key('stats-history'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReportScreen()),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Text(
                'Dosage history',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 14,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 18, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();
}
