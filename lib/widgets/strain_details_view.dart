import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/analytics_service.dart';
import '../domain/date_utils.dart';
import '../models/strain.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_dosage_form.dart';
import '../widgets/edit_strain_form.dart';
import '../widgets/sheet_header.dart';
import '../widgets/strain_mark.dart';

/// One strain, in full: identity header, use figures, dose-size spread,
/// stock toggle, and the three actions a strain owns — log a dose, edit,
/// delete. Opened as a bottom sheet through [showAppSheet], so the surface
/// is painted by the sheet itself, not here.
class StrainDetailsView extends StatelessWidget {
  final Strain strain;

  const StrainDetailsView({super.key, required this.strain});

  static final _gramFormat = NumberFormat('#,##0.0');
  static final _dateFormat = DateFormat('d MMM y');

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        // The copy passed in goes stale the moment stock is toggled; read
        // the live one so the switch reflects provider state.
        final live = provider.strains.firstWhere(
          (s) => s.id == strain.id,
          orElse: () => strain,
        );
        final insight = computeStrainInsight(strain.id, provider.dosages);

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader(
                leading: StrainMark(
                  shape: resolveLeafShape(strain.icon, strain.code),
                  color: legibleStrainColor(
                    Color(strain.color),
                    Theme.of(context).brightness,
                  ),
                  size: 28,
                ),
                title: strain.code,
                titleColor: legibleStrainColor(
                  Color(strain.color),
                  Theme.of(context).brightness,
                ),
                subtitle: strain.name == strain.code ? null : strain.name,
                trailing: IconButton(
                  key: const Key('strain-details-edit'),
                  tooltip: 'Edit strain',
                  icon: Icon(Icons.edit_outlined, color: c.textSecondary),
                  iconSize: 22,
                  onPressed: () {
                    final current = provider.getStrain(strain.id);
                    if (current == null) return;
                    Navigator.pop(context);
                    showAppSheet(
                      context,
                      builder: (_) => EditStrainForm(strain: current),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SheetHeader.inset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Eyebrow('Use'),
                    _FigureRow(label: 'Doses', value: '${insight.totalDoses}'),
                    _FigureRow(
                      label: 'Total',
                      value: '${_gramFormat.format(insight.totalGrams)}g',
                    ),
                    _FigureRow(
                      label: 'Average dose',
                      value: insight.totalDoses == 0
                          ? '—'
                          : '${_gramFormat.format(insight.avgDoseSize)}g',
                    ),
                    _FigureRow(
                      label: 'First used',
                      value: insight.firstUsed == null
                          ? '—'
                          : _dateFormat.format(insight.firstUsed!.toLocal()),
                    ),
                    _FigureRow(
                      label: 'Last used',
                      value: insight.lastUsed == null
                          ? '—'
                          : '${_dateFormat.format(insight.lastUsed!.toLocal())}'
                              '${_relative(insight.lastUsed!)}',
                    ),
                    const SizedBox(height: 24),
                    const _Eyebrow('Dose size'),
                    _DoseSpread(insight: insight),
                    const SizedBox(height: 24),
                    const _Eyebrow('Stock'),
                    SwitchListTile(
                      title: const Text('In stock'),
                      subtitle: const Text(
                        "Turn off when you don't have it on hand. Keeps the "
                        'history; drops it below the picker line.',
                      ),
                      value: live.inStock,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (inStock) => provider.setStrainInStock(
                        live.id,
                        inStock: inStock,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 48),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: c.caution,
                          ),
                          onPressed: () => _confirmDelete(
                            context,
                            provider,
                            strain,
                            insight.totalDoses,
                          ),
                          child: const Text('Delete strain'),
                        ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            showAppSheet(
                              context,
                              builder: (_) => AddDosageForm(
                                preselectedStrainId: strain.id,
                                day: DateTime.now(),
                              ),
                            );
                          },
                          child: const Text('Log a dose'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _relative(DateTime lastUsed) {
    // Calendar days in local time: a raw difference of local midnights is
    // 23h across a DST change and would floor "yesterday" to "today".
    final days = daysBetween(lastUsed, DateTime.now());
    return switch (days) {
      0 => ' (today)',
      1 => ' (yesterday)',
      _ => ' ($days days ago)',
    };
  }

  Future<void> _confirmDelete(
    BuildContext context,
    KratomProvider provider,
    Strain strain,
    int doseCount,
  ) async {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final doseClause = doseCount == 0
        ? 'It has no logged doses.'
        : 'Its $doseCount logged ${doseCount == 1 ? 'dose is' : 'doses are'} '
            'deleted too.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${strain.name}?'),
        content: Text(
          '$doseClause This cannot be undone.\n\n'
          'Create a backup in Manage first if you may want them back.',
          style: TextStyle(color: dialogContext.c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.c.caution,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await provider.deleteStrain(strain.id);
      if (context.mounted && route?.isCurrent == true) navigator.pop();
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not delete ${strain.name}')),
        );
      }
    }
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: sectionLabelStyle(context),
      ),
    );
  }
}

/// One figure in the use list: quiet label left, value right on a hairline
/// baseline shared with the rows around it.
class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppType.sans,
              fontSize: 14,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: AppType.sans,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
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
        style: TextStyle(
          fontFamily: AppType.sans,
          fontSize: 14,
          color: c.textTertiary,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SpreadFigure(
              label: 'p25',
              value: '${spread.p25.toStringAsFixed(1)}g',
            ),
            const SizedBox(width: 32),
            _SpreadFigure(
              label: 'median',
              value: '${spread.median.toStringAsFixed(1)}g',
            ),
            const SizedBox(width: 32),
            _SpreadFigure(
              label: 'p75',
              value: '${spread.p75.toStringAsFixed(1)}g',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Half of your doses of this strain fall between '
          '${spread.p25.toStringAsFixed(1)}g and ${spread.p75.toStringAsFixed(1)}g; '
          'the median is ${spread.median.toStringAsFixed(1)}g.',
          style: TextStyle(
            fontFamily: AppType.sans,
            fontSize: 13,
            height: 1.4,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// A bare percentile figure — serif number over a quiet label, no box.
class _SpreadFigure extends StatelessWidget {
  const _SpreadFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppType.display(size: 22, color: c.textPrimary)),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppType.sans,
            fontSize: 12,
            color: c.textTertiary,
          ),
        ),
      ],
    );
  }
}
