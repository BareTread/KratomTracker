import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/kratom_provider.dart';
import '../widgets/add_dosage_form.dart';
import '../widgets/add_strain_form.dart';
import '../widgets/edit_dosage_form.dart';
import '../widgets/timeline_painter.dart';
import '../widgets/edit_profile_sheet.dart';
import '../models/dosage.dart';
import '../models/strain.dart';
import '../constants/icons.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:ui';
import 'package:lottie/lottie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _showOptions = false;
  late AnimationController _animationController;
  late AnimationController _plantAnimationController;
  late DateTime _focusedDay;
  late PageController _pageController;
  final Duration _animationDuration = const Duration(milliseconds: 200);

  // Define these at the top of the class for consistency
  final Color _mainFabColor = const Color(0xFF00ACC1); // Vibrant cyan
  final Color _addDoseColor = const Color(0xFF5E35B1); // Rich violet
  final Color _addStrainColor = const Color(0xFF43A047); // Natural green

  // Remove unused animation controllers and animations
  late AnimationController _scaleController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _plantAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    // Initialize animation controllers for FAB menu
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Initialize with today's date
    final now = DateTime.now();
    _focusedDay = now;
    
    // Initialize page controller with today as the center
    final initialPage = 10000;
    _pageController = PageController(
      initialPage: initialPage,
      viewportFraction: 1.0,
    );

    // Set initial selected date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<KratomProvider>(context, listen: false).setSelectedDate(now);
    });

    // Only start animations when widget is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scaleController.repeat(reverse: true);
        _floatController.repeat(reverse: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pause animations when app is in background
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _plantAnimationController.dispose();
    _pageController.dispose();
    _scaleController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // Helper method to calculate date from page index
  DateTime _getDateFromIndex(int index) {
    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final difference = index - 10000; // Subtract initial page
    return cleanToday.add(Duration(days: difference));
  }

  Widget _buildCalendarSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 2,
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TableCalendar<dynamic>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                currentDay: DateTime.now(),
                calendarFormat: CalendarFormat.week,
                availableCalendarFormats: const {
                  CalendarFormat.week: 'Week',
                },
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronVisible: true,
                  rightChevronVisible: true,
                  titleTextStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.grey, size: 20),
                  rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  headerMargin: EdgeInsets.zero,
                  headerPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                calendarBuilders: CalendarBuilders(
                  headerTitleBuilder: (context, day) {
                    return Center(
                      child: InkWell(
                        onTap: () => _showMonthPicker(context, day),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('MMMM yyyy').format(day),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_focusedDay, selectedDay)) {
                    final currentIndex = _pageController.page?.round() ?? 10000;
                    final targetIndex = currentIndex + selectedDay.difference(_focusedDay).inDays;
                    
                    setState(() {
                      _focusedDay = selectedDay;
                    });
                    
                    // Force immediate page update
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _pageController.jumpToPage(targetIndex);
                      _pageController.animateToPage(
                        targetIndex,
                        duration: _animationDuration,
                        curve: Curves.easeOut,
                      );
                    });
                    
                    Provider.of<KratomProvider>(context, listen: false)
                        .setSelectedDate(selectedDay);
                  }
                },
                selectedDayPredicate: (day) => isSameDay(_focusedDay, day),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  isSameDay(_focusedDay, DateTime.now())
                      ? 'Today, ${DateFormat('d MMM').format(_focusedDay)}'
                      : DateFormat('d MMM').format(_focusedDay),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isSameDay(_focusedDay, DateTime.now()))
          Positioned(
            top: 0,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final difference = today.difference(_focusedDay).inDays;
                  final targetIndex = (_pageController.page?.round() ?? 10000) + difference;
                  
                  setState(() {
                    _focusedDay = today;
                  });
                  
                  _pageController.animateToPage(
                    targetIndex,
                    duration: _animationDuration,
                    curve: Curves.easeOut,
                  );
                  
                  Provider.of<KratomProvider>(context, listen: false)
                      .setSelectedDate(today);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.today,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              extendBody: true,
              appBar: AppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                title: InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const EditProfileSheet(),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[800],
                        child: const Icon(Icons.person_outline, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                provider.userName?.isNotEmpty == true 
                                    ? provider.userName! 
                                    : 'Guest',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white 
                                      : Colors.black87,
                                ),
                              ),
                              if (provider.userName?.isEmpty ?? true) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ],
                          ),
                          if (provider.userName?.isEmpty ?? true)
                            Text(
                              'Tap to customize',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ).withHover(),
                ),
                actions: const [],
              ),
              body: Column(
                children: [
                  _buildCalendarSection(),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const PageScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      pageSnapping: true,
                      onPageChanged: (index) {
                        final date = _getDateFromIndex(index);
                        if (!isSameDay(date, _focusedDay)) {
                          setState(() {
                            _focusedDay = date;
                          });
                          // Ensure provider is updated with clean date
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              Provider.of<KratomProvider>(context, listen: false)
                                  .setSelectedDate(date);
                            }
                          });
                        }
                      },
                      itemBuilder: (context, index) {
                        final date = _getDateFromIndex(index);
                        final dosages = provider.getDosagesForDate(date);

                        return TweenAnimationBuilder<double>(
                          duration: _animationDuration,
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return AnimatedOpacity(
                              duration: _animationDuration,
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - value)),
                                child: child!,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: dosages.isEmpty
                                ? _buildEmptyState()
                                : _buildDosagesList(dosages, provider),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_showOptions)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showOptions = false);
                    _animationController.reverse();
                  },
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 16,
              bottom: 24,
              child: _buildFABMenu(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[900]?.withOpacity(0.3)  // Keep dark mode
                            : Colors.grey[100]?.withOpacity(0.3),  // Light mode
                        shape: BoxShape.circle,
                      ),
                      child: Lottie.asset(
                        'assets/animations/empty_doses.json',
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                        controller: _plantAnimationController,
                        onLoaded: (composition) {
                          _plantAnimationController
                            ..duration = composition.duration * 4  // 4x slower
                            ..forward()
                            ..repeat();
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No doses recorded',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add your first dose',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklySparkline(KratomProvider provider) {
    final now = DateTime.now();
    final weekData = <double>[];
    
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayTotal = provider.getDosagesForDate(date)
          .fold(0.0, (sum, d) => sum + d.amount);
      weekData.add(dayTotal);
    }
    
    // Handle empty data safely
    if (weekData.isEmpty) return const SizedBox.shrink();
    
    final thisWeekTotal = weekData.fold(0.0, (a, b) => a + b);
    final maxValue = weekData.fold(0.0, (a, b) => a > b ? a : b);
    
    final lastWeekData = <double>[];
    for (int i = 13; i >= 7; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayTotal = provider.getDosagesForDate(date)
          .fold(0.0, (sum, d) => sum + d.amount);
      lastWeekData.add(dayTotal);
    }
    final lastWeekTotal = lastWeekData.fold(0.0, (a, b) => a + b);
    
    final percentChange = lastWeekTotal > 0 
        ? ((thisWeekTotal - lastWeekTotal) / lastWeekTotal * 100)
        : 0.0;
    
    final trendColor = percentChange > 10 
        ? Colors.amber[400]!
        : percentChange < -10 
            ? Colors.green[400]!
            : Colors.grey[400]!;
    
    final spots = weekData.asMap().entries.map((e) => 
        FlSpot(e.key.toDouble(), e.value)).toList();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]?.withOpacity(0.5)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.show_chart, color: Colors.grey[500], size: 18),
          const SizedBox(width: 10),
          Text(
            '${thisWeekTotal.toStringAsFixed(1)}g',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'this week',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
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
                  maxY: maxValue > 0 ? maxValue * 1.2 : 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: const LineTouchData(enabled: false),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: trendColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  percentChange >= 0 ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: trendColor,
                ),
                const SizedBox(width: 3),
                Text(
                  '${percentChange.abs().toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSinceLastDose(KratomProvider provider) {
    final allDosages = provider.dosages;
    if (allDosages.isEmpty) return const SizedBox.shrink();
    
    final sortedDosages = allDosages.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final lastDose = sortedDosages.first;
    final timeSince = DateTime.now().difference(lastDose.timestamp);
    
    String text;
    Color color;
    IconData icon;
    
    if (timeSince.inDays > 0) {
      text = '${timeSince.inDays}d ${timeSince.inHours % 24}h ago';
      color = Colors.grey;
      icon = Icons.history;
    } else if (timeSince.inHours >= 4) {
      text = '${timeSince.inHours}h ${timeSince.inMinutes % 60}m ago';
      color = Colors.green[400]!;
      icon = Icons.check_circle_outline;
    } else if (timeSince.inHours >= 2) {
      text = '${timeSince.inHours}h ${timeSince.inMinutes % 60}m ago';
      color = Colors.amber[400]!;
      icon = Icons.schedule;
    } else {
      final mins = timeSince.inMinutes;
      text = mins < 1 ? 'Just now' : '${mins}m ago';
      color = Colors.grey[400]!;
      icon = Icons.access_time;
    }
    
    // Safely get strain, return empty widget if not found
    Strain? strain;
    try {
      strain = provider.getStrain(lastDose.strainId);
    } catch (e) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]?.withOpacity(0.5)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last dose',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$text · ${strain.code}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Color(strain.color).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${lastDose.amount}g',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(strain.color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTimelineCard(List<Dosage> dosages, KratomProvider provider) {
    final dailyTotal = dosages.fold(0.0, (sum, dosage) => sum + dosage.amount);
    final dosageHeights = _calculateDosageHeights(dosages);

    final timelineDosages = dosages.map((dosage) {
      final strain = provider.getStrain(dosage.strainId);
      return (
        timestamp: dosage.timestamp,
        amount: dosage.amount,
        color: Color(strain.color),
        height: dosageHeights[dosage.id] ?? 0.0,
      );
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Timeline',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1A1A)  // Keep dark mode
                      : Colors.grey[200],  // Light mode
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${dailyTotal.toStringAsFixed(1)}g',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white  // Keep dark mode
                        : Colors.black,  // Light mode
                  ),
                ),
              ),
            ],
          ),
        ),
        // Timeline
        SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomPaint(
              size: const Size(double.infinity, 32),
              painter: TimelinePainter(
                morningColor: Colors.blue,
                afternoonColor: Colors.orange,
                eveningColor: Colors.purple,
                nightColor: Colors.indigo,
                dosages: timelineDosages,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDosagesList(List<Dosage> dosages, KratomProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 12,
        left: 0,
        right: 0,
        bottom: 100,
      ),
      itemCount: dosages.length + 3,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildTimeSinceLastDose(provider);
        }
        if (index == 1) {
          return _buildWeeklySparkline(provider);
        }
        if (index == 2) {
          return _buildDailyTimelineCard(dosages, provider);
        }
        final dosage = dosages[index - 3];
        final strain = provider.getStrain(dosage.strainId);
        final timeStr = DateFormat('h:mm a').format(dosage.timestamp);
        
        // Get time period
        final period = _getPeriod(dosage.timestamp);
        
        // Show period label if first item or if period changed
        final showPeriod = index == 3 || 
                         _getPeriod(dosages[index - 4].timestamp) != period;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showPeriod)
              Padding(
                padding: const EdgeInsets.only(
                  left: 8,
                  top: 16,
                  bottom: 8,
                ),
                child: Text(
                  period,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).cardColor  // Keep dark mode
                  : Colors.white,  // Light mode
              child: InkWell(
                onTap: () => _showDosageOptions(context, dosage, provider),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Strain Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(strain.color).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          strainIcons[strain.icon] ?? Icons.local_florist,
                          color: Color(strain.color),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Strain Info with Note Preview
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  strain.code,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (dosage.notes?.isNotEmpty ?? false) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.note_outlined,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                if (dosage.notes?.isNotEmpty ?? false) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showNotePopup(
                                        context, 
                                        dosage.notes!, 
                                        Color(strain.color).value,
                                      ),
                                      child: Text(
                                        dosage.notes!.length > 30 
                                            ? '${dosage.notes!.substring(0, 30)}...'
                                            : dosage.notes!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[400],
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Dosage Amount
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Color(strain.color),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${dosage.amount}g',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getPeriod(DateTime time) {
    final hour = time.hour;
    return hour < 12 ? 'Morning' : 
           hour < 17 ? 'Afternoon' : 
           hour < 21 ? 'Evening' : 'Night';
  }

  void _showDosageOptions(BuildContext context, Dosage dosage, KratomProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Dose'),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => EditDosageForm(dosage: dosage),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Delete Dose'),
                    content: const Text(
                      'Are you sure you want to delete this dose?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context)
                            ..pop() // Close dialog
                            ..pop(); // Close bottom sheet
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          provider.deleteDosage(dosage.id);
                          Navigator.of(context)
                            ..pop() // Close dialog
                            ..pop(); // Close bottom sheet
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dose deleted'),
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.all(8),
                            ),
                          );
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, double> _calculateDosageHeights(List<Dosage> dosages) {
    if (dosages.isEmpty) return {};

    final heights = <String, double>{};
    final maxDosage = dosages.fold(0.0, (max, d) => d.amount > max ? d.amount : max);
    final minDosage = dosages.fold(maxDosage, (min, d) => d.amount < min ? d.amount : min);
    
    // Handle single dosage case
    if (dosages.length == 1) {
      // Use a default height for single dosage
      heights[dosages.first.id] = 24.0; // A reasonable middle height
      return heights;
    }
    
    // Calculate the range and adjust scaling based on ratio
    final range = maxDosage - minDosage;
    final ratio = maxDosage / minDosage;
    
    // Define height bounds
    const minHeight = 12.0;
    const maxHeight = 32.0;
    final heightRange = maxHeight - minHeight;
    
    // Apply logarithmic scaling for better visualization
    for (var dosage in dosages) {
      if (ratio > 5) {
        // Use logarithmic scale for large differences
        final logScale = log(dosage.amount / minDosage) / log(ratio);
        heights[dosage.id] = minHeight + (heightRange * logScale);
      } else {
        // Use linear scale for smaller differences
        // Handle case where range is 0 (all doses are the same amount)
        if (range == 0) {
          heights[dosage.id] = minHeight + (heightRange * 0.5); // Middle height
        } else {
          final normalizedValue = (dosage.amount - minDosage) / range;
          heights[dosage.id] = minHeight + (heightRange * normalizedValue);
        }
      }
    }
    
    return heights;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _scaleController.stop();
      _floatController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _scaleController.repeat(reverse: true);
      _floatController.repeat(reverse: true);
    }
  }

  Widget _buildFABMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_showOptions) ...[
          // Add Strain Option
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black45,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: const Text(
                    'Add Strain',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'addStrain',
                  onPressed: () {
                    setState(() => _showOptions = false);
                    _animationController.reverse();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const AddStrainForm(),
                    );
                  },
                  backgroundColor: _addStrainColor.withOpacity(0.95),
                  elevation: 4,
                  child: const Icon(Icons.local_florist, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Add Dose Option
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black45,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: const Text(
                    'Add Dose',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'addDose',
                  onPressed: () {
                    setState(() => _showOptions = false);
                    _animationController.reverse();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const AddDosageForm(),
                    );
                  },
                  backgroundColor: _addDoseColor.withOpacity(0.95),
                  elevation: 4,
                  child: const Icon(Icons.add, size: 24),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Main FAB with blur background
        Stack(
          alignment: Alignment.center,
          children: [
            // Blurred background - make it exactly match FAB size and shape
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  width: 56, // Standard FAB size
                  height: 56, // Standard FAB size
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent, // Remove the black background
                  ),
                ),
              ),
            ),
            // Main FAB
            FloatingActionButton(
              onPressed: () {
                setState(() => _showOptions = !_showOptions);
                if (_showOptions) {
                  _animationController.forward();
                } else {
                  _animationController.reverse();
                }
              },
              backgroundColor: _mainFabColor,
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 150),
                turns: _showOptions ? 0.125 : 0,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Add this method to show the note popup
  void _showNotePopup(BuildContext context, String note, int strainColor) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color(strainColor).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(strainColor).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notes,
                      color: Color(strainColor),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Note',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(strainColor),
                      ),
                    ),
                  ],
                ),
              ),
              // Note content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  note,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
              // Close button
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: Color(strainColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add this method to show the month picker
  Future<void> _showMonthPicker(BuildContext context, DateTime initialDate) async {
    if (!mounted) return;
    
    DateTime currentDate = initialDate;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<KratomProvider>(context, listen: false);
    
    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext dialogContext) {  // Use dialogContext instead
        return StatefulBuilder(
          builder: (dialogContext, setState) {  // Use dialogContext here too
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Month/Year Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () {
                              setState(() {
                                currentDate = DateTime(
                                  currentDate.year,
                                  currentDate.month - 1,
                                );
                              });
                            },
                          ),
                          Text(
                            DateFormat('MMMM yyyy').format(currentDate),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              setState(() {
                                currentDate = DateTime(
                                  currentDate.year,
                                  currentDate.month + 1,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // Rest of the calendar (weekday headers and days grid)
                    // ... keep existing code for weekday headers ...
                    
                    // Update the GridView.builder to use currentDate instead of initialDate
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _getDaysInMonth(currentDate),
                      itemBuilder: (context, index) {
                        final date = DateTime(
                          currentDate.year,
                          currentDate.month,
                          index + 1,
                        );
                        final isSelected = isSameDay(date, _focusedDay);
                        final isToday = isSameDay(date, DateTime.now());
                        
                        return InkWell(
                          onTap: () => Navigator.pop(context, date),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : isToday
                                      ? theme.colorScheme.primary.withOpacity(0.1)
                                      : null,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : isToday
                                          ? theme.colorScheme.primary
                                          : null,
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (selectedDate != null && !isSameDay(_focusedDay, selectedDate)) {
      final difference = selectedDate.difference(_focusedDay).inDays;
      final targetIndex = (_pageController.page?.round() ?? 10000) + difference;

      setState(() {
        _focusedDay = selectedDate;
      });

      _pageController.jumpToPage(targetIndex);
      provider.setSelectedDate(selectedDate);  // Use the provider we got earlier
    }
  }

  // Helper method to get days in month
  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }
}

extension HoverExtension on Widget {
  Widget withHover() {
    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() {}),
          onExit: (_) => setState(() {}),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: 1.0,
            child: this,
          ),
        );
      },
    );
  }
} 