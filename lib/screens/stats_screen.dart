import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import '../models/dosage.dart';
import 'package:intl/intl.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _SmoothScrollBehavior(),
      child: Consumer<KratomProvider>(
        builder: (context, provider, child) {
          final now = DateTime.now();
          final last30Days = provider.getDosagesForDateRange(
            now.subtract(const Duration(days: 30)),
            now,
          );

          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // Custom Sliver App Bar for status bar spacing
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).padding.top,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                pinned: true,
                elevation: 0,
                toolbarHeight: 0,
                collapsedHeight: 0,
              ),
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDailyIntakeCard(context, last30Days),
                      const SizedBox(height: 16),
                      _buildUsagePatternCard(context, provider),
                      const SizedBox(height: 16),
                      _buildAdditionalInsightsCard(context, provider, last30Days),
                      // Add bottom padding for navigation bar
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
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

  Widget _buildDailyIntakeCard(BuildContext context, List<Dosage> dosages) {
    // Calculate active days
    final activeDays = dosages
        .map((d) => DateTime(d.timestamp.year, d.timestamp.month, d.timestamp.day))
        .toSet()
        .length;

    // Calculate averages
    final totalAmount = dosages.fold(0.0, (sum, d) => sum + d.amount);
    final avgDailyActive = activeDays > 0 ? totalAmount / activeDays : 0.0;
    final avgDaily30Days = totalAmount / 30;

    // Calculate average doses per day
    final avgDosesActive = activeDays > 0 ? dosages.length / activeDays : 0.0;
    final avgDoses30Days = dosages.length / 30;

    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight_outlined,  // Changed from scale_balance_outlined
                  size: 20, 
                  color: Colors.teal[300],  // Changed color
                ),
                const SizedBox(width: 8),
                const Text(
                  'Daily Intake',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              context,
              'Average (Active Days)',
              '${avgDailyActive.toStringAsFixed(1)}g',
              subtitle: '$activeDays active days',
              icon: Icons.calendar_today_outlined,
            ),
            _buildStatRow(
              context,
              'Average (30 Days)',
              '${avgDaily30Days.toStringAsFixed(1)}g',
              subtitle: 'Including inactive days',
              icon: Icons.date_range_outlined,
            ),
            _buildStatRow(
              context,
              'Doses per Active Day',
              avgDosesActive.toStringAsFixed(1),
              subtitle: 'When using',
              icon: Icons.local_pharmacy_outlined,
            ),
            _buildStatRow(
              context,
              'Doses per Day (30d)',
              avgDoses30Days.toStringAsFixed(1),
              subtitle: 'Including inactive days',
              icon: Icons.medication_outlined,
            ),
            _buildStatRow(
              context,
              'Total Intake',
              '${totalAmount.toStringAsFixed(1)}g',
              subtitle: 'Last 30 days',
              icon: Icons.summarize_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsagePatternCard(BuildContext context, KratomProvider provider) {
    final now = DateTime.now();
    final today = provider.getDosagesForDate(now);
    final lastDose = today.isEmpty 
        ? provider.getDosagesForDate(now.subtract(const Duration(days: 1))).lastOrNull
        : today.last;

    // Calculate time since last dose
    final timeSinceLastDose = lastDose != null 
        ? now.difference(lastDose.timestamp)
        : null;

    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.query_stats,  // Changed to a more appropriate icon
                  size: 20,
                  color: Colors.blue[300],  // Changed color
                ),
                const SizedBox(width: 8),
                const Text(
                  'Usage Patterns',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Remove streak indicator and keep essential info
            if (timeSinceLastDose != null)
              _buildStatRow(
                context,
                'Time Since Last Dose',
                _formatTimeDifference(timeSinceLastDose),
                icon: Icons.timer_outlined,
              ),
            _buildStatRow(
              context,
              'Peak Usage Time',
              _calculatePeakTime(provider.dosages),
              subtitle: 'Most common dosing time',
              icon: Icons.schedule_outlined,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeDifference(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m ago';
    } else {
      return '${duration.inMinutes}m ago';
    }
  }

  String _calculatePeakTime(List<Dosage> dosages) {
    if (dosages.isEmpty) return 'No data';

    final hourCounts = <int, int>{};
    for (var dosage in dosages) {
      final hour = dosage.timestamp.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    final peakHour = hourCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    final time = DateTime(2024, 1, 1, peakHour);
    return DateFormat('h:mm a').format(time);
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value, {
    String? subtitle,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Keep dark mode exactly as it is
          color: isDark 
              ? Theme.of(context).colorScheme.surface.withOpacity(0.8)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              size: 20, 
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow(
    String label,
    String value, {
    String? subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateAverageTimeBetweenDoses(List<Dosage> dosages) {
    if (dosages.length < 2) return 'N/A';
    
    // Sort dosages by timestamp
    final sortedDosages = dosages.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Calculate time differences
    var totalMinutes = 0;
    var count = 0;
    
    for (var i = 1; i < sortedDosages.length; i++) {
      final diff = sortedDosages[i].timestamp.difference(sortedDosages[i-1].timestamp);
      // Only count if less than 24 hours (to exclude sleep periods)
      if (diff.inHours < 24) {
        totalMinutes += diff.inMinutes;
        count++;
      }
    }
    
    if (count == 0) return 'N/A';
    
    final avgMinutes = totalMinutes ~/ count;
    final hours = avgMinutes ~/ 60;
    final minutes = avgMinutes % 60;
    
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  String _getMostActiveDays(List<Dosage> dosages) {
    if (dosages.isEmpty) return 'N/A';
    
    final dayCount = <int, int>{};
    for (var dosage in dosages) {
      final weekday = dosage.timestamp.weekday;
      dayCount[weekday] = (dayCount[weekday] ?? 0) + 1;
    }
    
    final mostActive = dayCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
        
    return DateFormat('EEEE').format(DateTime(2024, 1, mostActive));
  }

  Widget _buildAdditionalInsightsCard(
    BuildContext context,
    KratomProvider provider,
    List<Dosage> dosages,
  ) {
    // Calculate most used strain
    final strainUsage = <String, int>{};
    for (var dosage in dosages) {
      strainUsage[dosage.strainId] = (strainUsage[dosage.strainId] ?? 0) + 1;
    }

    String? mostUsedStrainId;
    int mostUsedCount = 0;
    if (strainUsage.isNotEmpty) {
      final mostUsed = strainUsage.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      mostUsedStrainId = mostUsed.key;
      mostUsedCount = mostUsed.value;
    }

    // Calculate average time between doses
    final avgTimeBetweenDoses = _calculateAverageTimeBetweenDoses(dosages);

    // Get most active days
    final mostActiveDays = _getMostActiveDays(dosages);

    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline,  // Changed to insights icon
                  size: 20,
                  color: Colors.amber[300],  // Changed color
                ),
                const SizedBox(width: 8),
                const Text(
                  'Additional Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (mostUsedStrainId != null) ...[
              _buildInsightRow(
                'Most Used Strain',
                provider.getStrain(mostUsedStrainId).name,
                subtitle: '$mostUsedCount doses in 30 days',
                icon: Icons.star_outline,
              ),
            ],
            _buildInsightRow(
              'Average Time Between Doses',
              avgTimeBetweenDoses,
              icon: Icons.timer_outlined,
            ),
            _buildInsightRow(
              'Most Active Days',
              mostActiveDays,
              subtitle: 'Based on 30-day history',
              icon: Icons.calendar_today_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
} 