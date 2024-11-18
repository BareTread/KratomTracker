import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratom_provider.dart';
import '../widgets/add_strain_form.dart';
import '../models/strain.dart';
import 'package:lottie/lottie.dart';

final Map<String, IconData> strainIcons = {
  'Leaf': Icons.local_florist_outlined,
  'Natural': Icons.eco_outlined,
  'Plant': Icons.grass_outlined,
  'Organic': Icons.spa_outlined,
};

class StrainsScreen extends StatelessWidget {
  const StrainsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        final strains = provider.strains;
        
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Strains',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${strains.length} strain${strains.length != 1 ? 's' : ''} total',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            actions: [
              if (strains.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.search,
                    color: Colors.grey[400],
                  ),
                  onPressed: () {
                    // Implement search functionality
                  },
                ),
            ],
          ),
          
          body: strains.isEmpty
              ? _buildEmptyState(context)
              : _buildStrainsList(context, strains),
          
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.only(bottom: 24, left: 64, right: 64),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AddStrainForm(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add Strain',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Lottie.asset(
              'assets/animations/plant.json',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No strains added yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add your first strain to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrainsList(BuildContext context, List<Strain> strains) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: strains.length,
      itemBuilder: (context, index) {
        final strain = strains[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.grey[900]?.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showStrainDetails(context, strain),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Enhanced Strain Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(strain.color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Color(strain.color).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        strainIcons[strain.icon] ?? Icons.local_florist,
                        color: Color(strain.color),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Enhanced Strain Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strain.code,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (strain.name.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              strain.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // More Options Button
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      onPressed: () => _showStrainOptions(context, strain),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
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

  void _showStrainDetails(BuildContext context, Strain strain) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        strain.name,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[400],
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Add more strain details here
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Strain strain) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Strain',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${strain.name}?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<KratomProvider>(context, listen: false)
                  .deleteStrain(strain.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showStrainOptions(BuildContext context, Strain strain) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.white),
                title: const Text(
                  'Edit Strain',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Show edit form
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text(
                  'View Details',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showStrainDetails(context, strain);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Strain',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, strain);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
} 