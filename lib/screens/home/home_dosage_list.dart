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
      // Clear the FAB so the final row's amount pill is never covered.
      padding: const EdgeInsets.only(top: 4, bottom: 120),
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
                  padding: const EdgeInsets.only(left: 4, top: 14, bottom: 6),
                  child: Text(
                    period.toUpperCase(),
                    style: TextStyle(
                      color: context.c.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
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
        margin: const EdgeInsets.only(bottom: 6),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: strainColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    strainIcons[strain?.icon] ?? Icons.local_florist,
                    color: strainColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Optical top-align with the amount pill.
                      const SizedBox(height: 2),
                      Text(
                        code,
                        style: TextStyle(
                          color: context.c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              color: context.c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (gap != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _gapText,
                              style: TextStyle(
                                color: context.c.textTertiary,
                                fontSize: 13,
                              ),
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
                // Fixed right-column structure: amount pill always on the
                // same baseline; effect slot always below it.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
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
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _EffectAffordance(
                      dosage: dosage,
                      effect: effect,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact, quiet effect entry point on a dose row. Shows nothing for doses
/// taken less than 45 minutes ago — there is nothing to report yet. The slot
/// always occupies the same vertical band so amount pills stay aligned.
class _EffectAffordance extends StatelessWidget {
  const _EffectAffordance({
    required this.dosage,
    required this.effect,
  });

  final Dosage dosage;
  final Effect? effect;

  static const _threshold = Duration(minutes: 45);
  static const _slotHeight = 20.0;

  @override
  Widget build(BuildContext context) {
    Widget? content;
    if (effect != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => EffectLogSheet.show(
          context,
          dosageId: dosage.id,
          existing: effect,
        ),
        child: _EffectSummary(effect: effect!),
      );
    } else if (DateTime.now().difference(dosage.timestamp) >= _threshold) {
      content = GestureDetector(
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
      );
    }

    return SizedBox(
      height: _slotHeight,
      child: content == null
          ? null
          : Align(
              alignment: Alignment.bottomRight,
              child: content,
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
