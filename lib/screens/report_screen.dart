import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import 'package:intl/intl.dart';
import '../constants/icons.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    // Default to last 30 days
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showDateRangePicker(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with date range
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${DateFormat('d MMM').format(_startDate)} – ${DateFormat('d MMM yyyy').format(_endDate)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          // Dosage List
          Expanded(
            child: Consumer<KratomProvider>(
              builder: (context, provider, child) {
                final dosages = provider.getDosagesForDateRange(_startDate, _endDate);
                dosages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                if (dosages.isEmpty) {
                  return Center(
                    child: Text(
                      'No doses recorded in this period',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                // Group dosages by date
                final groupedDosages = <String, List<dynamic>>{};
                for (var dosage in dosages) {
                  final date = DateFormat('d MMM').format(dosage.timestamp);
                  if (!groupedDosages.containsKey(date)) {
                    groupedDosages[date] = [];
                  }
                  groupedDosages[date]!.add(dosage);
                }

                return ListView.builder(
                  itemCount: groupedDosages.length,
                  itemBuilder: (context, index) {
                    final date = groupedDosages.keys.elementAt(index);
                    final dayDosages = groupedDosages[date]!;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...dayDosages.map((dosage) {
                          final strain = provider.getStrain(dosage.strainId);
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Color(strain.color).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                strainIcons[strain.icon],
                                color: Color(strain.color),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              strain.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('HH:mm').format(dosage.timestamp),
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(strain.color).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${dosage.amount}g',
                                style: TextStyle(
                                  color: Color(strain.color),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              surface: Theme.of(context).colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
} 