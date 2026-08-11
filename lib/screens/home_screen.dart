import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dosage.dart';
import '../models/strain.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_dosage_form.dart';
import '../widgets/add_strain_form.dart';
import 'home/home_day_card.dart';
import 'home/home_dosage_list.dart';
import 'home/home_empty_state.dart';
import 'home/home_fab_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _todayPage = 10000;

  late final PageController _pageController;
  late DateTime _focusedDay;
  final _fabKey = GlobalKey<HomeFabMenuState>();
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateUtils.dateOnly(DateTime.now());
    _pageController = PageController(initialPage: _todayPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<KratomProvider>().setSelectedDate(_focusedDay);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _dateForPage(int index) => DateUtils.dateOnly(DateTime.now())
      .add(Duration(days: index - _todayPage));

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _selectDay(DateTime day) {
    final cleanDay = DateUtils.dateOnly(day);
    if (_sameDay(cleanDay, _focusedDay)) return;
    final current = _pageController.page?.round() ?? _todayPage;
    final target = current + cleanDay.difference(_focusedDay).inDays;
    final adjacent = (target - current).abs() == 1;
    setState(() => _focusedDay = cleanDay);
    context.read<KratomProvider>().setSelectedDate(cleanDay);
    if (!_pageController.hasClients) return;
    if (adjacent && !AppMotion.reduced(context)) {
      _pageController.animateToPage(
        target,
        duration: AppMotion.normal,
        curve: AppMotion.spring,
      );
    } else {
      _pageController.jumpToPage(target);
    }
  }

  void _openAddDose() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddDosageForm(),
      );

  void _openAddStrain() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddStrainForm(),
      );

  @override
  Widget build(BuildContext context) {
    // Reserve space so the vine list never draws under the bottom bar.
    const barBodyHeight = 68.0;

    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                HomeDayCard(
                  focusedDay: _focusedDay,
                  onDaySelected: _selectDay,
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _todayPage + 1,
                    physics: const PageScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    onPageChanged: (index) {
                      final day = _dateForPage(index);
                      if (_sameDay(day, _focusedDay)) return;
                      setState(() => _focusedDay = day);
                      context.read<KratomProvider>().setSelectedDate(day);
                    },
                    itemBuilder: (context, index) => _HomeDayPage(
                      key: ValueKey(_dateForPage(index)),
                      date: _dateForPage(index),
                      onAddDose: _openAddDose,
                    ),
                  ),
                ),
                // Spacer matching the overlaid bottom bar so content clears it.
                SizedBox(
                  height: barBodyHeight +
                      MediaQuery.paddingOf(context).bottom * 0.15,
                ),
              ],
            ),
          ),
        ),
        if (_fabOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _fabKey.currentState?.close(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        // Bottom bar lives above the dim overlay so the expanded menu stays
        // tappable and the day total remains readable.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _DayBottomBar(
            date: _focusedDay,
            fabKey: _fabKey,
            onAddDose: _openAddDose,
            onAddStrain: _openAddStrain,
            onFabVisibilityChanged: (visible) {
              if (_fabOpen != visible) setState(() => _fabOpen = visible);
            },
          ),
        ),
      ],
    );
  }
}

/// Day total on the left, labelled Add Dose pill on the right. Replaces the
/// floating FAB that used to cover the last vine row.
class _DayBottomBar extends StatelessWidget {
  const _DayBottomBar({
    required this.date,
    required this.fabKey,
    required this.onAddDose,
    required this.onAddStrain,
    required this.onFabVisibilityChanged,
  });

  final DateTime date;
  final GlobalKey<HomeFabMenuState> fabKey;
  final VoidCallback onAddDose;
  final VoidCallback onAddStrain;
  final ValueChanged<bool> onFabVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    context.select<KratomProvider, int>((p) {
      final doses = p.getDosagesForDate(date);
      return Object.hashAll(doses);
    });
    final doses = context.read<KratomProvider>().getDosagesForDate(date);
    final total = doses.fold<double>(0, (sum, d) => sum + d.amount);
    final count = doses.length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 16, 10 + bottomInset * 0.15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: count == 0
                    ? Text(
                        'No doses yet',
                        style: TextStyle(
                          color: context.c.textTertiary,
                          fontSize: 13,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatAmount(total),
                            style: TextStyle(
                              color: context.c.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'across $count ${count == 1 ? 'dose' : 'doses'}',
                            style: TextStyle(
                              color: context.c.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            HomeFabMenu(
              key: fabKey,
              onAddDose: onAddDose,
              onAddStrain: onAddStrain,
              onVisibilityChanged: onFabVisibilityChanged,
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double value) {
    final body = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '${body}g';
  }
}

class _HomeDayPage extends StatelessWidget {
  const _HomeDayPage({
    super.key,
    required this.date,
    required this.onAddDose,
  });

  final DateTime date;
  final VoidCallback onAddDose;

  @override
  Widget build(BuildContext context) {
    context.select<KratomProvider, int>((provider) {
      final doses = provider.getDosagesForDate(date);
      return Object.hashAll(doses);
    });
    context.select<KratomProvider, int>(
      (provider) => Object.hashAll(provider.strains),
    );
    final provider = context.read<KratomProvider>();
    final dosages = provider.getDosagesForDate(date);
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(date, today);

    // Today with no doses still shows a young shoot + NOW; past empty days
    // keep the existing empty-state CTA.
    if (dosages.isEmpty && !isToday) {
      return HomeEmptyState(onAddDose: onAddDose);
    }

    final strains = <String, Strain>{
      for (final strain in provider.strains) strain.id: strain,
    };
    final duration =
        AppMotion.reduced(context) ? Duration.zero : AppMotion.normal;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: AppMotion.spring,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: HomeDosageList(
          dosages: List<Dosage>.unmodifiable(dosages),
          strainsById: strains,
          isToday: isToday,
          header: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
