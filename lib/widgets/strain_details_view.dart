import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/strain.dart';
import '../providers/kratom_provider.dart';
import '../widgets/add_dosage_form.dart';
import '../constants/icons.dart';
import '../widgets/edit_strain_form.dart';

class StrainDetailsView extends StatelessWidget {
  final Strain strain;

  const StrainDetailsView({
    super.key,
    required this.strain,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        // Get all dosages for this strain
        final strainDosages = provider.dosages
            .where((d) => d.strainId == strain.id)
            .toList();

        // Calculate statistics
        final totalDoses = strainDosages.length;
        final lastDose = strainDosages.isNotEmpty 
            ? strainDosages.reduce((a, b) => 
                a.timestamp.isAfter(b.timestamp) ? a : b)
            : null;
        
        // Calculate last 30 days consumption
        final now = DateTime.now();
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        final last30DaysDosages = strainDosages
            .where((d) => d.timestamp.isAfter(thirtyDaysAgo))
            .toList();
        final last30DaysTotal = last30DaysDosages.fold(
            0.0, (sum, dose) => sum + dose.amount);

        return SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(strain.color).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Color(strain.color).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(strain.color).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          strainIcons[strain.icon] ?? Icons.local_florist,
                          color: Color(strain.color),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strain.code,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              strain.name,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: Color(strain.color),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => EditStrainForm(strain: strain),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // Statistics
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(strain.color),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        title: 'Total Uses',
                        value: '$totalDoses times',
                        icon: Icons.history,
                        color: strain.color,
                      ),
                      if (lastDose != null) ...[
                        const SizedBox(height: 12),
                        _buildStatCard(
                          title: 'Last Taken',
                          value: DateFormat('MMM d, y').format(lastDose.timestamp),
                          subtitle: '${lastDose.amount}g at ${DateFormat('h:mm a').format(lastDose.timestamp)}',
                          icon: Icons.access_time,
                          color: strain.color,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildStatCard(
                        title: 'Last 30 Days',
                        value: '${last30DaysTotal.toStringAsFixed(1)}g',
                        subtitle: '${last30DaysDosages.length} doses',
                        icon: Icons.calendar_today,
                        color: strain.color,
                      ),
                    ],
                  ),
                ),
                
                // Add Dose Button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddDosageForm(
                            preselectedStrainId: strain.id,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(strain.color),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Add Dose',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required int color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(color).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(color).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Color(color),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
} 