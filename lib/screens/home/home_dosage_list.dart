import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/icons.dart';
import '../../models/dosage.dart';
import '../../models/strain.dart';
import '../../theme/app_theme.dart';
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
                  padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
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
    final semantics = '$time, $code, ${dosage.amount} grams'
        '${gap == null ? '' : ', ${_gapText.substring(1)} since previous dose'}';
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
                        Row(
                          children: [
                            Text(
                              code,
                              style: TextStyle(
                                color: context.c.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (dosage.notes?.isNotEmpty ?? false) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.note_outlined,
                                size: 16,
                                color: context.c.textTertiary,
                              ),
                            ],
                          ],
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
                        if (dosage.notes?.isNotEmpty ?? false)
                          InkWell(
                            onTap: () => showNotePopup(
                              context,
                              dosage.notes!,
                              strainColor,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  dosage.notes!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.c.textTertiary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: strainColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${dosage.amount}g',
                      style: TextStyle(
                        color: strainColor.computeLuminance() > 0.45
                            ? Colors.black
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
