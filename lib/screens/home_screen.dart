import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/date_utils.dart';
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
  const HomeScreen({super.key, this.clock});

  /// Test seam for the wall clock. Production leaves this null.
  @visibleForTesting
  final DateTime Function()? clock;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _todayPage = 10000;

  late final PageController _pageController;

  /// Drives the day card only. Deliberately not setState: rebuilding this
  /// State rebuilds the PageView subtree, and onPageChanged fires *during*
  /// the slide — that mid-flight rebuild was the hitch in the transition.
  late final ValueNotifier<DateTime> _focusedDay;

  /// The one clock the live "time since" labels listen to. Ticks once a
  /// minute while the app is visible and jumps the moment it resumes, so a
  /// "2m since last dose" frozen from hours in the background can't happen.
  /// Only the two small label subtrees rebuild on a tick, never the pages.
  late final ValueNotifier<DateTime> _now;
  Timer? _nowTimer;

  /// Calendar day that page [_todayPage] maps to. Frozen until midnight
  /// (timer tick or resume) re-anchors it, so the last page stays "today".
  late DateTime _anchor;

  final _fabKey = GlobalKey<HomeFabMenuState>();
  bool _fabOpen = false;

  DateTime _wallClock() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = _wallClock();
    _anchor = startOfDay(now);
    _focusedDay = ValueNotifier(_anchor);
    _now = ValueNotifier(now);
    _pageController = PageController(initialPage: _todayPage);
    WidgetsBinding.instance.addObserver(this);
    _startNowTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _commitSelectedDate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopNowTimer();
    _pageController.dispose();
    _focusedDay.dispose();
    _now.dispose();
    super.dispose();
  }

  void _startNowTimer() {
    _stopNowTimer();
    final delay = _delayUntilNextMinute(_wallClock());
    _nowTimer = Timer(delay, () {
      if (!mounted) return;
      _onNowTick();
      _startNowTimer();
    });
  }

  void _stopNowTimer() {
    _nowTimer?.cancel();
    _nowTimer = null;
  }

  void _onNowTick() {
    if (!mounted) return;
    _syncToWallClock();
  }

  /// Align labels and the page→date mapping with the wall clock. Called on
  /// every minute tick and on resume so an instance left running across
  /// midnight lands on the real today.
  void _syncToWallClock() {
    final now = _wallClock();
    final today = startOfDay(now);
    _now.value = now;
    if (today == _anchor) return;

    _anchor = today;
    _focusedDay.value = today;
    setState(() {});
    if (_pageController.hasClients &&
        (_pageController.page?.round() ?? _todayPage) != _todayPage) {
      _pageController.jumpToPage(_todayPage);
    }
    _commitSelectedDate();
  }

  static Duration _delayUntilNextMinute(DateTime now) {
    final ms = now.second * 1000 + now.millisecond;
    return Duration(milliseconds: 60000 - ms);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      // Hours may have passed with the app backgrounded; don't wait a
      // full tick for the labels to catch up, and re-align the next tick
      // to the wall-clock minute.
      _syncToWallClock();
      _startNowTimer();
    } else if (state != AppLifecycleState.inactive) {
      // Paused/hidden/detached: stop waking the isolate every minute.
      _stopNowTimer();
    }
  }

  /// Publish the day to the provider. This notifies every listener in the
  /// app, so it waits for the slide to settle; nothing on screen needs it
  /// live (only the add-dose sheet reads `selectedDate`, at open time).
  void _commitSelectedDate() {
    final provider = context.read<KratomProvider>();
    if (_sameDay(provider.selectedDate, _focusedDay.value)) return;
    provider.setSelectedDate(_focusedDay.value);
  }

  // Calendar days, not elapsed hours: Duration(days: n) is 24h each and
  // slips a page either side of a DST transition. Derived from [_anchor]
  // so a live clock crossing midnight cannot shift every page by one.
  DateTime _dateForPage(int index) => addDays(_anchor, index - _todayPage);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _selectDay(DateTime day) {
    final cleanDay = startOfDay(day);
    var target = _todayPage + daysBetween(_anchor, cleanDay);
    if (target < 0) target = 0;
    if (target > _todayPage) target = _todayPage;
    final mapped = _dateForPage(target);
    if (_sameDay(mapped, _focusedDay.value)) return;
    final current = _pageController.page?.round() ?? _todayPage;
    final adjacent = (target - current).abs() == 1;
    _focusedDay.value = mapped;
    if (!_pageController.hasClients) {
      _commitSelectedDate();
      return;
    }
    if (adjacent && !AppMotion.reduced(context)) {
      // ScrollEndNotification commits the date when the slide settles.
      _pageController.animateToPage(
        target,
        duration: AppMotion.normal,
        curve: AppMotion.spring,
      );
    } else {
      _pageController.jumpToPage(target);
      _commitSelectedDate();
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
    return Stack(
      children: [
        Scaffold(
          // Parent MainScreen owns the bottom nav + system inset; don't pad
          // the body again or the vine list shrinks for no reason.
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                ValueListenableBuilder<DateTime>(
                  valueListenable: _focusedDay,
                  builder: (context, day, _) => HomeDayCard(
                    focusedDay: day,
                    onDaySelected: _selectDay,
                    now: _now,
                  ),
                ),
                Expanded(
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: (_) {
                      _commitSelectedDate();
                      return false;
                    },
                    child: PageView.builder(
                      key: const Key('home-day-pager'),
                      controller: _pageController,
                      itemCount: _todayPage + 1,
                      physics: const PageScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      onPageChanged: (index) {
                        final day = _dateForPage(index);
                        if (_sameDay(day, _focusedDay.value)) return;
                        _focusedDay.value = day;
                      },
                      // Each day is its own layer, so a slide composites
                      // cached pictures instead of re-running every vine
                      // and leaf painter on both pages, every frame.
                      itemBuilder: (context, index) => RepaintBoundary(
                        child: _HomeDayPage(
                          key: ValueKey(_dateForPage(index)),
                          date: _dateForPage(index),
                          today: _anchor,
                          onAddDose: _openAddDose,
                          now: _now,
                        ),
                      ),
                    ),
                  ),
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
        // Circular FAB, bottom-right above the nav bar. Right edge aligns
        // with the calendar card; the bottom sits at 24 so the disc and its
        // bloom clear the nav bar instead of crowding "Manage".
        Positioned(
          right: 16,
          bottom: 24,
          child: HomeFabMenu(
            key: _fabKey,
            onAddDose: _openAddDose,
            onAddStrain: _openAddStrain,
            onVisibilityChanged: (visible) {
              if (_fabOpen != visible) setState(() => _fabOpen = visible);
            },
          ),
        ),
      ],
    );
  }
}

class _HomeDayPage extends StatelessWidget {
  const _HomeDayPage({
    super.key,
    required this.date,
    required this.today,
    required this.onAddDose,
    required this.now,
  });

  final DateTime date;
  final DateTime today;
  final VoidCallback onAddDose;

  /// Ticking clock for the live gap label; see [_HomeScreenState].
  final ValueListenable<DateTime> now;

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
          now: now,
          header: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
