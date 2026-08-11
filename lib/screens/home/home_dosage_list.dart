import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/dosage.dart';
import '../../models/effect.dart';
import '../../models/strain.dart';
import '../../providers/kratom_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/effect_log_sheet.dart';
import '../../widgets/strain_mark.dart';
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
      padding: const EdgeInsets.only(top: 10, bottom: 120),
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
                  padding: const EdgeInsets.only(left: 4, top: 18, bottom: 8),
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
    context.select<KratomProvider, int>(
      (p) => Object.hashAll(p.effectsForDosage(dosage.id)),
    );
    final effect =
        context.read<KratomProvider>().effectsForDosage(dosage.id).firstOrNull;
    final semantics = '$time, $code, ${dosage.amount} grams'
        '${gap == null ? '' : ', ${_gapText.substring(1)} since previous dose'}'
        '${effect == null ? '' : ', effect logged'}';
    final showAffordance = effect != null ||
        DateTime.now().difference(dosage.timestamp) >=
            _EffectAffordance.threshold;
    return Semantics(
      button: true,
      label: semantics,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: context.c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.c.hairline),
        ),
        child: InkWell(
          onTap: () => showDosageOptions(context, dosage),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            showDosageOptions(context, dosage);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: strainColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: StrainMark(
                      shape: resolveLeafShape(
                        strain?.icon ?? '',
                        strain?.code ?? '',
                      ),
                      color: strainColor,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        code,
                        style: TextStyle(
                          color: context.c.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              color: context.c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (gap != null)
                            Text(
                              '  ·  $_gapText',
                              style: TextStyle(
                                color: context.c.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AmountPill(amount: dosage.amount, strain: strain),
                    if (showAffordance)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _EffectAffordance(
                          dosage: dosage,
                          effect: effect,
                        ),
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

/// The amount as a solid object: a saturated fill in the strain's own colour
/// with text picked for contrast. Strain colours are chosen to work as fills,
/// so the pill is where their full saturation belongs.
class _AmountPill extends StatelessWidget {
  const _AmountPill({required this.amount, required this.strain});

  final double amount;
  final Strain? strain;

  static Color _textOn(Color fill) => fill.computeLuminance() > 0.2
      ? const Color(0xFF10151A)
      : const Color(0xFFF5F7F8);

  @override
  Widget build(BuildContext context) {
    final fill = strain == null ? context.c.hairline : Color(strain!.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${amount}g',
        style: TextStyle(
          color: strain == null ? context.c.textPrimary : _textOn(fill),
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// Quiet, text-only effect entry point tucked under the amount pill. Shown
/// only when there is something to do or report — no reserved slot, no icon.
class _EffectAffordance extends StatelessWidget {
  const _EffectAffordance({
    required this.dosage,
    required this.effect,
  });

  final Dosage dosage;
  final Effect? effect;

  static const threshold = Duration(minutes: 45);

  @override
  Widget build(BuildContext context) {
    if (effect != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => EffectLogSheet.show(
          context,
          dosageId: dosage.id,
          existing: effect,
        ),
        child: _EffectSummary(effect: effect!),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => EffectLogSheet.show(
        context,
        dosageId: dosage.id,
      ),
      child: Padding(
        // Keep the small text comfortably tappable.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          'Log how it felt',
          style: TextStyle(
            color: context.c.textTertiary,
            fontSize: 11,
          ),
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
