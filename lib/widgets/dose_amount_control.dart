import 'package:flutter/material.dart';

import '../models/dosage.dart';
import '../theme/app_theme.dart';

/// Trim, accept `,` or `.` as the decimal separator.
double? parseDoseAmount(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Shared amount validation used by add + edit forms.
String? validateDoseAmount(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter an amount';
  }
  final amount = parseDoseAmount(value);
  if (amount == null || !amount.isFinite) {
    return 'Please enter a valid number';
  }
  if (amount <= 0) {
    return 'Amount must be greater than zero';
  }
  if (amount > 100) {
    return 'Amount seems too high (max 100g)';
  }
  return null;
}

/// Up to two decimals, trailing zeros stripped (`16.60` → `16.6`, `2.0` → `2`).
String formatDoseAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Distinct amounts from [strainId]'s doses, newest first, at most three.
/// Nothing is excluded: the dose being edited stays in the list.
List<double> recentDoseAmounts(Iterable<Dosage> dosages, String strainId) {
  final doses = dosages.where((d) => d.strainId == strainId).toList();
  doses.sort((a, b) {
    final byTime = b.timestamp.compareTo(a.timestamp);
    if (byTime != 0) return byTime;
    return b.id.compareTo(a.id);
  });
  final seen = <double>{};
  final out = <double>[];
  for (final dose in doses) {
    if (!seen.add(dose.amount)) continue;
    out.add(dose.amount);
    if (out.length == 3) break;
  }
  return out;
}

/// Large serif amount figure with ±0.1 g steppers and up to three recent chips.
///
/// [label] is the field label and semantics string. The add sheet uses
/// `Amount`; the edit sheet passes `Amount (g)` so existing finders keep
/// matching the field.
class DoseAmountControl extends StatelessWidget {
  const DoseAmountControl({
    super.key,
    required this.controller,
    required this.recentAmounts,
    this.label = 'Amount',
  });

  final TextEditingController controller;
  final List<double> recentAmounts;
  final String label;

  static const minusKey = Key('dose-amount-minus');
  static const plusKey = Key('dose-amount-plus');
  static const fieldKey = Key('dose-amount-field');
  static const double _fieldWidth = 168;

  void _nudge(double delta) {
    final parsed = parseDoseAmount(controller.text);
    final current = (parsed != null && parsed.isFinite) ? parsed : 0;
    final stepped = ((current + delta) * 100).round() / 100;
    final clamped = stepped.clamp(0.1, 100.0);
    controller.text = formatDoseAmount(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final chips = recentAmounts.take(3);
    const tabular = [FontFeature.tabularFigures()];
    final fieldStyle =
        AppType.display(size: 44, color: c.textPrimary, height: 1.1)
            .copyWith(fontFeatures: tabular);
    // Typographic, not a form box: no fill, no floating label, one hairline
    // under the figure. The label lives in semantics only.
    final underline = UnderlineInputBorder(
      borderSide: BorderSide(color: c.hairline),
    );
    final caution = UnderlineInputBorder(
      borderSide: BorderSide(color: c.caution),
    );
    final unitStyle = TextStyle(
      fontFamily: AppType.sans,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: c.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StepButton(
              key: minusKey,
              tooltip: 'Decrease by 0.1 g',
              icon: Icons.remove,
              onPressed: () => _nudge(-0.1),
            ),
            // The figure and its small "g" are set tight as one group
            // ("15.8g", like the Home rows) and centred between the
            // steppers: the text is end-aligned against the suffix and the
            // right padding is half the field's spare width. The hairline
            // and any error line keep the full field width.
            Expanded(
              child: Center(
                child: SizedBox(
                  width: _fieldWidth,
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final dir = Directionality.of(context);
                      final scaler = MediaQuery.textScalerOf(context);
                      double widthOf(String text, TextStyle style) {
                        final tp = TextPainter(
                          text: TextSpan(text: text, style: style),
                          textDirection: dir,
                          textScaler: scaler,
                          maxLines: 1,
                        )..layout();
                        final w = tp.width;
                        tp.dispose();
                        return w;
                      }

                      final shown =
                          controller.text.isEmpty ? '\u2013' : controller.text;
                      final group = widthOf(shown, fieldStyle) +
                          widthOf('g', unitStyle) +
                          4;
                      final spare =
                          (_fieldWidth - group).clamp(0.0, _fieldWidth);
                      return Semantics(
                        label: label,
                        textField: true,
                        child: TextFormField(
                          key: fieldKey,
                          controller: controller,
                          textAlign: TextAlign.end,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: fieldStyle,
                          cursorColor: c.textPrimary,
                          validator: validateDoseAmount,
                          decoration: InputDecoration(
                            filled: false,
                            hintText: '\u2013',
                            hintStyle:
                                fieldStyle.copyWith(color: c.textTertiary),
                            suffixText: 'g',
                            suffixStyle: unitStyle,
                            errorStyle: TextStyle(
                              fontFamily: AppType.sans,
                              fontSize: 12,
                              color: c.caution,
                            ),
                            errorMaxLines: 2,
                            isDense: true,
                            contentPadding: EdgeInsets.only(
                              top: 4,
                              bottom: 6,
                              right: spare / 2,
                            ),
                            border: underline,
                            enabledBorder: underline,
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: c.textSecondary),
                            ),
                            errorBorder: caution,
                            focusedErrorBorder: caution,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            _StepButton(
              key: plusKey,
              tooltip: 'Increase by 0.1 g',
              icon: Icons.add,
              onPressed: () => _nudge(0.1),
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final amount in chips)
                _RecentChip(
                  label: '${formatDoseAmount(amount)}g',
                  onTap: () => controller.text = formatDoseAmount(amount),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 48 dp round stepper, hairline ring, quiet glyph.
class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        foregroundColor: c.textSecondary,
        fixedSize: const Size(48, 48),
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: CircleBorder(side: BorderSide(color: c.hairline)),
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // 48 dp tap target around a 34 dp hairline pill.
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: c.hairline)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppType.sans,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
