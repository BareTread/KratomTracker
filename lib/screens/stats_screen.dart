import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        final dosages = provider.dosages;
        final last30Days = dosages.where((d) =>
          d.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 30)))
        ).toList();

        // Calculate statistics
        double totalUsage = 0;
        final dailyUsage = <DateTime, double>{};
        final now = DateTime.now();
        
        // Get unique dates with usage
        final uniqueDates = last30Days.map((d) => DateTime(
          d.timestamp.year,
          d.timestamp.month,
          d.timestamp.day,
        )).toSet();

        // Initialize days with actual usage
        for (var date in uniqueDates) {
          dailyUsage[date] = 0;
        }

        // Fill in actual usage
        for (var dosage in last30Days) {
          final date = DateTime(
            dosage.timestamp.year,
            dosage.timestamp.month,
            dosage.timestamp.day,
          );
          dailyUsage[date] = (dailyUsage[date] ?? 0) + dosage.amount;
          totalUsage += dosage.amount;
        }

        // Calculate daily average based on days with actual usage
        final daysWithUsage = uniqueDates.length;
        final dailyAverage = daysWithUsage > 0 ? totalUsage / daysWithUsage : 0;

        // Prepare chart data with better visualization
        final spots = <FlSpot>[];
        for (int i = -29; i <= 0; i++) {
          final date = DateTime(
            now.year,
            now.month,
            now.day,
          ).add(Duration(days: i));
          spots.add(FlSpot(
            i.toDouble(),
            dailyUsage[date] ?? 0,
          ));
        }

        // Find most used strain
        final strainUsage = <String, double>{};
        for (var dosage in last30Days) {
          strainUsage[dosage.strainId] = 
            (strainUsage[dosage.strainId] ?? 0) + dosage.amount;
        }

        String mostUsedStrainName = 'None';
        Color mostUsedStrainColor = Theme.of(context).colorScheme.primary;
        
        if (strainUsage.isNotEmpty) {
          final mostUsedStrainId = strainUsage.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
          final mostUsedStrain = provider.strains
              .firstWhere((s) => s.id == mostUsedStrainId);
          mostUsedStrainName = mostUsedStrain.name;
          mostUsedStrainColor = Color(mostUsedStrain.color);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Statistics'),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last ${daysWithUsage > 1 ? "30" : daysWithUsage} ${daysWithUsage > 1 ? "Days" : "Day"}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _StatItem(
                                title: 'Total Usage',
                                value: '${totalUsage.toStringAsFixed(1)}g',
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              _StatItem(
                                title: 'Daily Average',
                                value: '$dailyAverage g',
                                subtitle: '$daysWithUsage ${daysWithUsage > 1 ? "days" : "day"}',
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              _StatItem(
                                title: 'Most Used',
                                value: mostUsedStrainName,
                                color: mostUsedStrainColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Usage History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 300,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 5,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey.withOpacity(0.2),
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 5,
                                      reservedSize: 40,
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 7,
                                      getTitlesWidget: (value, meta) {
                                        final date = now.add(
                                          Duration(days: value.toInt()),
                                        );
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            DateFormat('MM/dd').format(date),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    color: Theme.of(context).colorScheme.primary,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter: (spot, percent, barData, index) {
                                        return FlDotCirclePainter(
                                          radius: 4,
                                          color: Theme.of(context).colorScheme.primary,
                                          strokeWidth: 2,
                                          strokeColor: Colors.white,
                                        );
                                      },
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    ),
                                  ),
                                ],
                                minY: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Color color;

  const _StatItem({
    required this.title,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
} 