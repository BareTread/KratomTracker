import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/kratom_provider.dart';
import '../widgets/add_dosage_form.dart';
import '../widgets/add_strain_form.dart';
import '../widgets/edit_dosage_form.dart';
import '../widgets/timeline_painter.dart';
import '../models/dosage.dart';
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
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Initialize with today's date
    final now = DateTime.now();
    _focusedDay = now;
    
    // Initialize page controller with today as the center
    final initialPage = 10000;
    _pageController = PageController(
      initialPage: initialPage,
      viewportFraction: 0.99,
    );

    // Set initial selected date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<KratomProvider>(context, listen: false).setSelectedDate(now);
    });
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
    final difference = index - 10000; // Subtract initial page
    return DateTime(
      today.year,
      today.month,
      today.day + difference,
    );
  }

  Widget _buildCalendarSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
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
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            currentDay: DateTime.now(),
            calendarFormat: CalendarFormat.week,
            availableCalendarFormats: const {
              CalendarFormat.week: 'Week',
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 16),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.grey, size: 20),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              headerMargin: EdgeInsets.zero,
              headerPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            calendarStyle: CalendarStyle(
              cellMargin: const EdgeInsets.symmetric(vertical: 2),
              cellPadding: EdgeInsets.zero,
              defaultTextStyle: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black87,  // Dark text for light mode
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,  // Keep white for selected day in both modes
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              todayTextStyle: const TextStyle(
                color: Colors.white,  // Keep white for today in both modes
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              outsideDaysVisible: false,
              holidayTextStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black87,  // Dark text for light mode
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              Provider.of<KratomProvider>(context, listen: false)
                  .setSelectedDate(selectedDay);
              final difference = selectedDay.difference(DateTime.now()).inDays;
              _pageController.jumpToPage(10000 + difference);
            },
            selectedDayPredicate: (day) => isSameDay(_focusedDay, day),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black87,  // Dark text for light mode
              ),
              weekendStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black87,  // Dark text for light mode
              ),
              dowTextFormatter: (date, locale) => 
                  DateFormat.E(locale).format(date)[0],
            ),
            daysOfWeekHeight: 16,
            rowHeight: 32,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Today, ${DateFormat('d MMM').format(_focusedDay)}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
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
                title: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      child: const Icon(Icons.person_outline, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Alin',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.black87,  // Dark text for light mode
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Stack(
                      children: [
                        const Icon(Icons.notifications_outlined, color: Colors.grey),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
              body: Column(
                children: [
                  _buildCalendarSection(),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        final date = _getDateFromIndex(index);
                        if (!isSameDay(date, _focusedDay)) {
                          setState(() {
                            _focusedDay = date;
                          });
                          provider.setSelectedDate(date);
                        }
                      },
                      itemBuilder: (context, index) {
                        final date = _getDateFromIndex(index);
                        final dosages = provider.getDosagesForDate(date);

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
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
      itemCount: dosages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildDailyTimelineCard(dosages, provider);
        }
        final dosage = dosages[index - 1];
        final strain = provider.getStrain(dosage.strainId);
        final timeStr = DateFormat('h:mm a').format(dosage.timestamp);
        
        // Get time period
        final period = _getPeriod(dosage.timestamp);
        
        // Show period label if first item or if period changed
        final showPeriod = index == 1 || 
                         _getPeriod(dosages[index - 2].timestamp) != period;

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
      _plantAnimationController.stop();
      _animationController.stop();
      _scaleController.stop();
      _floatController.stop();
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
} 