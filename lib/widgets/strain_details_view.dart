import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/analytics_service.dart';
import '../models/strain.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_dosage_form.dart';
import '../widgets/edit_strain_form.dart';
import '../widgets/strain_mark.dart';

class StrainDetailsView extends StatelessWidget {
  final Strain strain;

  const StrainDetailsView({super.key, required this.strain});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        final insight = computeStrainInsight(
          strain.id,
          provider.dosages,
        );

        return SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(strain: strain),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(strain: strain, text: 'Statistics'),
                      const SizedBox(height: 16),
                      _StatsGrid(strain: strain, insight: insight),
                      const SizedBox(height: 20),
                      _SectionTitle(strain: strain, text: 'Dose size spread'),
                      const SizedBox(height: 12),
                      _DoseSpread(insight: insight),
                    ],
                  ),
                ),
                _AddDoseButton(strain: strain),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.strain});

  final Strain strain;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(strain.color).withValues(alpha: 0.2),
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
              color: Color(strain.color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(strain.color).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: StrainMark(
                shape: resolveLeafShape(strain.icon, strain.code),
                color: Color(strain.color),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strain.code,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                ),
                Text(
                  strain.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: Color(strain.color)),
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => EditStrainForm(strain: strain),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.strain, required this.text});

  final Strain strain;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Color(strain.color),
          ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.strain, required this.insight});

  final Strain strain;
  final StrainInsight insight;

  @override
  Widget build(BuildContext context) {
    final color = Color(strain.color);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatChip(
          title: 'Total doses',
          value: '${insight.totalDoses}',
          icon: Icons.history,
          color: color,
        ),
        _StatChip(
          title: 'Total grams',
          value: '${insight.totalGrams.toStringAsFixed(1)}g',
          icon: Icons.monitor_weight_outlined,
          color: color,
        ),
        _StatChip(
          title: 'Avg dose size',
          value: insight.totalDoses == 0
              ? '—'
              : '${insight.avgDoseSize.toStringAsFixed(1)}g',
          icon: Icons.local_pharmacy_outlined,
          color: color,
        ),
        _StatChip(
          title: 'First used',
          value: insight.firstUsed == null
              ? '—'
              : DateFormat('MMM d, y').format(insight.firstUsed!),
          icon: Icons.play_arrow_outlined,
          color: color,
        ),
        _StatChip(
          title: 'Last used',
          value: insight.lastUsed == null
              ? '—'
              : DateFormat('MMM d, y').format(insight.lastUsed!),
          icon: Icons.access_time,
          color: color,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: (MediaQuery.sizeOf(context).width - 48 - 12) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseSpread extends StatelessWidget {
  const _DoseSpread({required this.insight});

  final StrainInsight insight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final spread = insight.doseSpread;
    if (spread == null) {
      return Text(
        'No doses logged yet.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.textTertiary,
            ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _spreadChip(context, 'p25', '${spread.p25.toStringAsFixed(1)}g'),
            const SizedBox(width: 8),
            _spreadChip(
              context,
              'median',
              '${spread.median.toStringAsFixed(1)}g',
              emphasized: true,
            ),
            const SizedBox(width: 8),
            _spreadChip(context, 'p75', '${spread.p75.toStringAsFixed(1)}g'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Half of your doses of this strain fall between '
          '${spread.p25.toStringAsFixed(1)}g and ${spread.p75.toStringAsFixed(1)}g; '
          'the median is ${spread.median.toStringAsFixed(1)}g.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _spreadChip(
    BuildContext context,
    String label,
    String value, {
    bool emphasized = false,
  }) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: emphasized ? c.accent.withValues(alpha: 0.12) : c.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textTertiary,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _AddDoseButton extends StatelessWidget {
  const _AddDoseButton({required this.strain});

  final Strain strain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
              builder: (_) => AddDosageForm(preselectedStrainId: strain.id),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
