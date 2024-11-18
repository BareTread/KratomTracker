import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/kratom_provider.dart';
import '../widgets/add_dosage_form.dart';
import '../widgets/add_strain_form.dart';
import '../widgets/edit_dosage_form.dart';
import '../widgets/timeline_painter.dart';
import '../models/dosage.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _showOptions = false;
  late AnimationController _animationController;
  late DateTime _focusedDay;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize with today's date
    final now = DateTime.now();
    _focusedDay = now;
    
    // Initialize page controller with today as the center
    final initialPage = 10000; // Large number to allow "infinite" scrolling
    _pageController = PageController(
      initialPage: initialPage,
      viewportFraction: 0.99, // Slight peek of next/previous pages
    );

    // Set initial selected date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<KratomProvider>(context, listen: false).setSelectedDate(now);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
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
    return Container(
      margin: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
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
              defaultTextStyle: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              todayTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              outsideDaysVisible: false,
              holidayTextStyle: const TextStyle(color: Colors.white),
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
              weekdayStyle: const TextStyle(fontSize: 12),
              weekendStyle: const TextStyle(fontSize: 12),
              dowTextFormatter: (date, locale) => DateFormat.E(locale).format(date)[0],
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
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.grey[900],
            elevation: 0,
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  child: const Icon(Icons.person_outline, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Alin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
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
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showOptions) ...[
                // Add Strain Option
                FloatingActionButton.extended(
                  heroTag: 'addStrain',
                  onPressed: () {
                    setState(() => _showOptions = false);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      builder: (context) => const AddStrainForm(),
                    );
                  },
                  icon: const Icon(Icons.local_florist),
                  label: const Text('Add Strain'),
                  backgroundColor: const Color(0xFF4CAF50), // Green color
                ),
                const SizedBox(height: 12),
                // Add Dose Option
                FloatingActionButton.extended(
                  heroTag: 'addDose',
                  onPressed: () {
                    setState(() => _showOptions = false);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      builder: (context) => const AddDosageForm(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Dose'),
                  backgroundColor: const Color(0xFFFF1493), // Hot Pink
                ),
                const SizedBox(height: 16),
              ],
              // Main FAB
              FloatingActionButton(
                onPressed: () {
                  setState(() => _showOptions = !_showOptions);
                },
                backgroundColor: const Color(0xFFFF1493), // Hot Pink
                child: Icon(
                  _showOptions ? Icons.close : Icons.add,
                  color: Colors.white, // White icon for better contrast
                ),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // Position for better one-handed use
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty_doses.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 16),
          Text(
            'No doses recorded',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first dose',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
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
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${dailyTotal.toStringAsFixed(1)}g',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
    // Sort dosages by timestamp (morning first)
    final sortedDosages = List<Dosage>.from(dosages)
      ..sort((a, b) {
        // First sort by period (morning -> night)
        final periodA = _getPeriodValue(a.timestamp);
        final periodB = _getPeriodValue(b.timestamp);
        if (periodA != periodB) return periodA - periodB;
        // Then sort by time within each period
        return a.timestamp.compareTo(b.timestamp);
      });

    return Column(
      children: [
        _buildDailyTimelineCard(dosages, provider),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedDosages.length,
            itemBuilder: (context, index) {
              final dosage = sortedDosages[index];
              final strain = provider.getStrain(dosage.strainId);
              final timeStr = DateFormat('h:mm a').format(dosage.timestamp);
              
              // Get time period
              final hour = dosage.timestamp.hour;
              final period = hour < 12 ? 'Morning' : 
                         hour < 17 ? 'Afternoon' : 
                         hour < 21 ? 'Evening' : 'Night';
              
              // Show period label if first item or if period changed
              final showPeriod = index == 0 || 
                               _getPeriod(sortedDosages[index - 1].timestamp) != period;

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
                                Icons.local_florist,
                                color: Color(strain.color),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Strain Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strain.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
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
          ),
        ),
      ],
    );
  }

  // Helper method to get period value for sorting
  int _getPeriodValue(DateTime time) {
    final hour = time.hour;
    if (hour < 12) return 0; // Morning
    if (hour < 17) return 1; // Afternoon
    if (hour < 21) return 2; // Evening
    return 3; // Night
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
} 