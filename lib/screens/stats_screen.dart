import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import '../models/dosage.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        final now = DateTime.now();
        final last30Days = provider.getDosagesForDateRange(
          now.subtract(const Duration(days: 30)),
          now,
        );

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDailyIntakeStats(context, last30Days),
                const SizedBox(height: 16),
                _buildUsagePatternStats(context, last30Days),
                const SizedBox(height: 16),
                _buildStrainRotationStats(context, provider, last30Days),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyIntakeStats(BuildContext context, List<Dosage> dosages) {
    final activeDays = dosages
        .map((d) => DateTime(d.timestamp.year, d.timestamp.month, d.timestamp.day))
        .toSet()
        .length;

    final totalAmount = dosages.fold(0.0, (sum, d) => sum + d.amount);
    final avgDailyActive = activeDays > 0 ? totalAmount / activeDays : 0.0;
    final avgDaily30Days = totalAmount / 30;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scale_outlined, 
                  size: 20, 
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily Intake',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              'Average (Active Days)',
              '${avgDailyActive.toStringAsFixed(1)}g',
              subtitle: '$activeDays active days',
              icon: Icons.calendar_today_outlined,
            ),
            _buildStatRow(
              'Average (30 Days)',
              '${avgDaily30Days.toStringAsFixed(1)}g',
              subtitle: 'Including inactive days',
              icon: Icons.date_range_outlined,
            ),
            _buildStatRow(
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

  Widget _buildUsagePatternStats(BuildContext context, List<Dosage> dosages) {
    final hourlyUsage = <int, int>{};
    for (var dosage in dosages) {
      final hour = dosage.timestamp.hour;
      hourlyUsage[hour] = (hourlyUsage[hour] ?? 0) + 1;
    }

    final sortedHours = hourlyUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate doses per active day
    final activeDays = dosages
        .map((d) => DateTime(d.timestamp.year, d.timestamp.month, d.timestamp.day))
        .toSet()
        .length;
    final avgDosesPerActiveDay = activeDays > 0 ? dosages.length / activeDays : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Usage Patterns',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sortedHours.isNotEmpty) ...[
              _buildStatRow(
                'Peak Usage Time',
                _formatHour(sortedHours[0].key),
                subtitle: '${sortedHours[0].value} doses',
                icon: Icons.schedule_outlined,
              ),
            ],
            _buildStatRow(
              'Doses per Active Day',
              avgDosesPerActiveDay.toStringAsFixed(1),
              subtitle: 'Average when using',
              icon: Icons.local_pharmacy_outlined,
            ),
            _buildStatRow(
              'Average Doses/Day',
              (dosages.length / 30).toStringAsFixed(1),
              subtitle: 'Over 30 days',
              icon: Icons.trending_up_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrainRotationStats(
    BuildContext context,
    KratomProvider provider,
    List<Dosage> dosages,
  ) {
    final strainUsage = <String, List<Dosage>>{};
    for (var dosage in dosages) {
      strainUsage.putIfAbsent(dosage.strainId, () => []).add(dosage);
    }

    // Calculate effectiveness metrics
    final strainEffectiveness = strainUsage.map((id, doses) {
      final strain = provider.getStrain(id);
      final avgAmount = doses.fold(0.0, (sum, d) => sum + d.amount) / doses.length;
      final frequency = doses.length;
      
      return MapEntry(strain.name, {
        'avgAmount': avgAmount,
        'frequency': frequency,
        'lastUsed': doses.map((d) => d.timestamp).reduce((a, b) => a.isAfter(b) ? a : b),
      });
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics_outlined, 
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Strain Insights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showStrainAnalysisInfo(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStrainEffectivenessChart(strainEffectiveness),
            const Divider(height: 24),
            _buildStrainRotationMetrics(strainUsage, provider),
            if (strainEffectiveness.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildStrainRecommendations(context, strainEffectiveness),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrainEffectivenessChart(Map<String, Map<String, dynamic>> effectiveness) {
    // Implement a visual chart showing strain usage patterns
    // Could be a mini bar chart or radar chart
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: effectiveness.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final strain = effectiveness.entries.elementAt(index);
          return _buildStrainEffectivenessBar(
            strain.key,
            strain.value['frequency'] as int,
            strain.value['avgAmount'] as double,
          );
        },
      ),
    );
  }

  Widget _buildStrainRecommendations(
    BuildContext context,
    Map<String, Map<String, dynamic>> effectiveness,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommendations',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildRecommendationCard(
          context,
          title: 'Rotation Opportunity',
          description: 'Consider rotating between your top strains more frequently',
          icon: Icons.swap_horiz,
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, {String? subtitle, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
          ],
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

  String _formatHour(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:00 $period';
  }

  void _showStrainAnalysisInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Understanding Strain Analysis'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Strain Effectiveness shows how often you use each strain'),
              SizedBox(height: 8),
              Text('• Rotation Score indicates how well you vary your strains'),
              SizedBox(height: 8),
              Text('• Recommendations are based on your usage patterns'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.secondary,
        ),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }

  Widget _buildStrainRotationMetrics(Map<String, List<Dosage>> strainUsage, KratomProvider provider) {
    final uniqueStrains = strainUsage.length;
    final totalStrains = provider.strains.length;
    final rotationScore = totalStrains > 0 
        ? (uniqueStrains / totalStrains * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow(
          'Strain Rotation',
          '$rotationScore%',
          subtitle: '$uniqueStrains of $totalStrains strains used',
          icon: Icons.swap_horiz_outlined,
        ),
      ],
    );
  }

  Widget _buildStrainEffectivenessBar(String strainName, int frequency, double avgAmount) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: 60 * (frequency / 10), // Scale height based on frequency
            width: 20,
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strainName,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${avgAmount.toStringAsFixed(1)}g',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
} 