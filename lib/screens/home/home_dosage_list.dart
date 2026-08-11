import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/icons.dart';
import '../../models/dosage.dart';
import '../../models/effect.dart';
import '../../models/strain.dart';
import '../../providers/kratom_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/effect_log_sheet.dart';
import 'home_dose_actions.dart';

class HomeDosageList extends StatelessWidget {
  const HomeDosageList({
    super.key,
    required this.dosages,
    required this.strainsById,
    required this.header,
  });

  final List<Dosage> dosages;
  final Map<String, Strain> strainsById;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final sorted = [...dosages]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      itemCount: sorted.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        final row = index - 1;
        final dosage = sorted[row];
        final previous = row == 0 ? null : sorted[row - 1];
        final period = _period(dosage.timestamp);
        final showPeriod =
            previous == null || _period(previous.timestamp) != period;
        return _EntranceRow(
          index: row,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showPeriod)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 20, bottom: 8),
                  child: Text(
                    period,
                    style: TextStyle(
                      color: context.c.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              _DoseCard(
                dosage: dosage,
                strain: strainsById[dosage.strainId],
                gap: previous == null
                    ? null
                    : dosage.timestamp.difference(previous.timestamp),
              ),
            ],
          ),
        );
      },
    );
  }

  String _period(DateTime time) => time.hour < 12
      ? 'Morning'
      : time.hour < 17
          ? 'Afternoon'
          : time.hour < 21
              ? 'Evening'
              : 'Night';
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.dosage,
    required this.strain,
    required this.gap,
  });

  final Dosage dosage;
  final Strain? strain;
  final Duration? gap;

  String get _gapText {
    if (gap == null) return '';
    final hours = gap!.inHours;
    final minutes = gap!.inMinutes.remainder(60);
    return hours > 0 ? '+${hours}h ${minutes}m' : '+${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final code = strain?.code ?? 'Unknown strain';
    final strainColor =
        strain == null ? context.c.textTertiary : Color(strain!.color);
    final time = DateFormat.jm().format(dosage.timestamp);
    final brightness = Theme.of(context).brightness;
    final chipColors = strainChipColors(strainColor, brightness);
    context.select<KratomProvider, int>(
      (p) => Object.hashAll(p.effectsForDosage(dosage.id)),
    );
    final effect =
        context.read<KratomProvider>().effectsForDosage(dosage.id).firstOrNull;
    final semantics = '$time, $code, ${dosage.amount} grams'
        '${gap == null ? '' : ', ${_gapText.substring(1)} since previous dose'}'
        '${effect == null ? '' : ', effect logged'}';
    return Semantics(
      button: true,
      label: semantics,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: context.c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.c.hairline),
        ),
        child: InkWell(
          onTap: () => showDosageOptions(context, dosage),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            showDosageOptions(context, dosage);
          },
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: strainColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      strainIcons[strain?.icon] ?? Icons.local_florist,
                      color: strainColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code,
                          style: TextStyle(
                            color: context.c.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              time,
                              style: TextStyle(color: context.c.textSecondary),
                            ),
                            if (gap != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _gapText,
                                style: TextStyle(color: context.c.textTertiary),
                              ),
                            ],
                          ],
                        ),
                        if (dosage.notes?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(
                            dosage.notes!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.c.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: chipColors.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${dosage.amount}g',
                          style: TextStyle(
                            color: chipColors.foreground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _EffectAffordance(
                        dosage: dosage,
                        effect: effect,
                        foreground: chipColors.foreground,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact, quiet effect entry point on a dose row. Shows nothing for doses
/// taken less than 45 minutes ago — there is nothing to report yet.
class _EffectAffordance extends StatelessWidget {
  const _EffectAffordance({
    required this.dosage,
    required this.effect,
    required this.foreground,
  });

  final Dosage dosage;
  final Effect? effect;
  final Color foreground;

  static const _threshold = Duration(minutes: 45);

  @override
  Widget build(BuildContext context) {
    if (effect != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => EffectLogSheet.show(
            context,
            dosageId: dosage.id,
            existing: effect,
          ),
          child: _EffectSummary(effect: effect!),
        ),
      );
    }
    if (DateTime.now().difference(dosage.timestamp) < _threshold) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => EffectLogSheet.show(
          context,
          dosageId: dosage.id,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sentiment_satisfied_alt_outlined,
              size: 12,
              color: context.c.textTertiary,
            ),
            const SizedBox(width: 3),
            Text(
              'Log how it felt',
              style: TextStyle(
                color: context.c.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffectSummary extends StatelessWidget {
  const _EffectSummary({required this.effect});

  final Effect effect;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      'E${effect.energy}',
      'M${effect.mood}',
      'P${effect.painRelief}',
    ];
    if (effect.duration != null) {
      final hours = effect.duration!.inHours;
      parts.add(hours >= 1 ? '${hours}h' : '${effect.duration!.inMinutes}m');
    }
    return Text(
      parts.join(' · '),
      style: TextStyle(color: context.c.textTertiary, fontSize: 11),
    );
  }
}

class _EntranceRow extends StatefulWidget {
  const _EntranceRow({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_EntranceRow> createState() => _EntranceRowState();
}

class _EntranceRowState extends State<_EntranceRow> {
  bool _visible = false;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    final delay = AppMotion.reduced(context)
        ? Duration.zero
        : Duration(milliseconds: (widget.index * 20).clamp(0, 160));
    Future<void>.delayed(delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final duration =
        AppMotion.reduced(context) ? Duration.zero : AppMotion.normal;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: duration,
      curve: AppMotion.emphasized,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.04),
        duration: duration,
        curve: AppMotion.spring,
        child: widget.child,
      ),
    );
  }
}
