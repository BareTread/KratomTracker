import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dosage.dart';
import '../models/strain.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_dosage_form.dart';
import '../widgets/add_strain_form.dart';
import '../widgets/edit_profile_sheet.dart';
import 'home/home_calendar_section.dart';
import 'home/home_day_summary.dart';
import 'home/home_dosage_list.dart';
import 'home/home_empty_state.dart';
import 'home/home_fab_menu.dart';
import 'home/home_timeline_card.dart';

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
    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          appBar: AppBar(
            backgroundColor: context.c.surfaceRaised,
            elevation: 0,
            title: _ProfileTitle(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const EditProfileSheet(),
              ),
            ),
          ),
          body: Column(
            children: [
              HomeCalendarSection(
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
            ],
          ),
        ),
        if (_fabOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _fabKey.currentState?.close(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          ),
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

class _ProfileTitle extends StatelessWidget {
  const _ProfileTitle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = context.select<KratomProvider, String?>((p) => p.userName);
    final guest = name?.isNotEmpty != true;
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.c.surfaceSunken,
            child: Icon(Icons.person_outline, color: context.c.textSecondary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    guest ? 'Guest' : name!,
                    style: TextStyle(
                      color: context.c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (guest) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: context.c.textSecondary,
                    ),
                  ],
                ],
              ),
              if (guest)
                Text(
                  'Tap to customize',
                  style: TextStyle(
                    color: context.c.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
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
    if (dosages.isEmpty) return HomeEmptyState(onAddDose: onAddDose);
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: HomeDosageList(
          dosages: List<Dosage>.unmodifiable(dosages),
          strainsById: strains,
          header: Column(
            children: [
              const HomeDaySummary(),
              HomeTimelineCard(dosages: dosages, strainsById: strains),
            ],
          ),
        ),
      ),
    );
  }
}
