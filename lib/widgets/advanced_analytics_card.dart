import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import 'package:fl_chart/fl_chart.dart';

class AdvancedAnalyticsCard extends StatelessWidget {
  const AdvancedAnalyticsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        final weeklySummary = provider.getWeeklySummary();
        final monthlySummary = provider.getMonthlySummary();
        final peakTimes = provider.getPeakUsageTimes();
        final consecutiveDays = provider.getConsecutiveUsageDays();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly Summary Card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_view_week,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'This Week',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          'Total Doses',
                          '${weeklySummary['totalDosages']}',
                          Icons.local_florist,
                          Colors.green,
                        ),
                        _buildStatColumn(
                          'Total Amount',
                          '${weeklySummary['totalAmount'].toStringAsFixed(1)}g',
                          Icons.scale,
                          Colors.blue,
                        ),
                        _buildStatColumn(
                          'Days Active',
                          '${weeklySummary['daysActive']}/7',
                          Icons.check_circle,
                          Colors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Daily Average: ${weeklySummary['avgPerDay'].toStringAsFixed(2)}g',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // Monthly Summary Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'This Month',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          'Total Doses',
                          '${monthlySummary['totalDosages']}',
                          Icons.local_florist,
                          Colors.purple,
                        ),
                        _buildStatColumn(
                          'Total Amount',
                          '${monthlySummary['totalAmount'].toStringAsFixed(1)}g',
                          Icons.scale,
                          Colors.orange,
                        ),
                        _buildStatColumn(
                          'Days Active',
                          '${monthlySummary['daysActive']}/${monthlySummary['daysInMonth']}',
                          Icons.event_available,
                          Colors.pink,
                        ),
                      ],
                    ),
                    if (monthlySummary['daysActive'] > 0) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Daily Average: ${monthlySummary['avgPerDay'].toStringAsFixed(2)}g',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Consecutive Days Tracker
            if (consecutiveDays > 0)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: consecutiveDays >= 7 ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Consecutive Usage',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '$consecutiveDays',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: consecutiveDays >= 7 ? Colors.orange : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            consecutiveDays == 1 ? 'day' : 'days',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      if (consecutiveDays >= 7) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Consider taking a tolerance break',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.orange,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Peak Usage Times
            if (peakTimes.values.any((v) => v > 0))
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Usage Patterns',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: peakTimes.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final labels = peakTimes.keys.toList();
                                    if (value.toInt() >= 0 && value.toInt() < labels.length) {
                                      final label = labels[value.toInt()];
                                      // Extract just the time range
                                      final shortLabel = label.split(' ').first;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          shortLabel,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: peakTimes.entries.map((entry) {
                              final index = peakTimes.keys.toList().indexOf(entry.key);
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.toDouble(),
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 16,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
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
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
