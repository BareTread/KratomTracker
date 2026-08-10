import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/effect.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';

/// Minimal sheet for logging how a dose felt.
///
/// Ratings are 1–5 via a segmented dot selector. Unset stays null where the
/// model allows (focus, anxiety). Energy / mood / pain relief are always shown
/// and required to save. Duration is minutes, never averaged with ratings.
class EffectLogSheet extends StatefulWidget {
  final String dosageId;
  final Effect? existing;

  const EffectLogSheet({
    super.key,
    required this.dosageId,
    this.existing,
  });

  static Future<void> show(
    BuildContext context, {
    required String dosageId,
    Effect? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EffectLogSheet(
        dosageId: dosageId,
        existing: existing,
      ),
    );
  }

  @override
  State<EffectLogSheet> createState() => _EffectLogSheetState();
}

class _EffectLogSheetState extends State<EffectLogSheet> {
  static const _uuid = Uuid();

  late int? _energy;
  late int? _mood;
  late int? _painRelief;
  late int? _focus;
  late int? _anxiety;
  late int? _durationMinutes;
  late final TextEditingController _notesController;
  bool _showMore = false;
  bool _customDuration = false;
  late final TextEditingController _customDurationController;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _energy = existing?.energy;
    _mood = existing?.mood;
    _painRelief = existing?.painRelief;
    _focus = existing?.focus;
    _anxiety = existing?.anxiety;
    _durationMinutes = existing?.duration?.inMinutes;
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _customDurationController = TextEditingController();
    if (_durationMinutes != null &&
        !_presetDurations.contains(_durationMinutes)) {
      _customDuration = true;
      _customDurationController.text = '$_durationMinutes';
    }
    // Reveal optional metrics when they already have values.
    if (_focus != null || _anxiety != null) {
      _showMore = true;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  static const _presetDurations = [120, 180, 240, 300];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEdit ? 'Update how it felt' : 'How did it feel?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Optional notes on energy, mood, and relief — just for you.',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: 20),
            _DotRatingRow(
              label: EffectMetric.energy.label,
              value: _energy,
              onChanged: (v) => setState(() => _energy = v),
              allowClear: false,
            ),
            const SizedBox(height: 14),
            _DotRatingRow(
              label: EffectMetric.mood.label,
              value: _mood,
              onChanged: (v) => setState(() => _mood = v),
              allowClear: false,
            ),
            const SizedBox(height: 14),
            _DotRatingRow(
              label: EffectMetric.painRelief.label,
              value: _painRelief,
              onChanged: (v) => setState(() => _painRelief = v),
              allowClear: false,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showMore = !_showMore),
                icon: Icon(
                  _showMore
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(_showMore ? 'Less' : 'More'),
                style: TextButton.styleFrom(
                  foregroundColor: c.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const SizedBox(height: 4),
                  _DotRatingRow(
                    label: EffectMetric.focus.label,
                    value: _focus,
                    onChanged: (v) => setState(() => _focus = v),
                    allowClear: true,
                  ),
                  const SizedBox(height: 14),
                  _DotRatingRow(
                    label: EffectMetric.anxiety.label,
                    value: _anxiety,
                    onChanged: (v) => setState(() => _anxiety = v),
                    allowClear: true,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              crossFadeState: _showMore
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: AppMotion.reduced(context)
                  ? Duration.zero
                  : AppMotion.fast,
              sizeCurve: AppMotion.emphasized,
            ),
            const SizedBox(height: 8),
            Text(
              'Duration',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in _presetDurations)
                  _DurationChip(
                    label: minutes >= 300 ? '5h+' : '${minutes ~/ 60}h',
                    selected:
                        !_customDuration && _durationMinutes == minutes,
                    onTap: () => setState(() {
                      _customDuration = false;
                      _durationMinutes =
                          _durationMinutes == minutes ? null : minutes;
                    }),
                  ),
                _DurationChip(
                  label: 'Custom',
                  selected: _customDuration,
                  onTap: () => setState(() {
                    _customDuration = true;
                    if (_durationMinutes != null &&
                        _presetDurations.contains(_durationMinutes)) {
                      _durationMinutes = null;
                    }
                  }),
                ),
              ],
            ),
            if (_customDuration) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customDurationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Minutes',
                  filled: true,
                  fillColor: c.surfaceSunken,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.hairline),
                  ),
                ),
                onChanged: (raw) {
                  final parsed = int.tryParse(raw.trim());
                  setState(() {
                    _durationMinutes =
                        (parsed != null && parsed > 0) ? parsed : null;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
                filled: true,
                fillColor: c.surfaceSunken,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.hairline),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: c.caution, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _save,
              child: Text(_isEdit ? 'Save' : 'Save notes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_energy == null || _mood == null || _painRelief == null) {
      setState(() {
        _error = 'Rate energy, mood, and pain relief to save.';
      });
      return;
    }

    final notes = _notesController.text.trim();
    final effect = Effect(
      id: widget.existing?.id ?? _uuid.v4(),
      dosageId: widget.dosageId,
      timestamp: widget.existing?.timestamp ?? DateTime.now(),
      energy: _energy!,
      mood: _mood!,
      painRelief: _painRelief!,
      focus: _focus,
      anxiety: _anxiety,
      notes: notes.isEmpty ? null : notes,
      duration: _durationMinutes == null
          ? null
          : Duration(minutes: _durationMinutes!),
    );

    final provider = context.read<KratomProvider>();
    try {
      if (_isEdit) {
        await provider.updateEffect(effect);
      } else {
        await provider.addEffect(effect);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not save right now.');
      return;
    }

    if (!mounted) return;
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.pop(context);
  }
}

class _DotRatingRow extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool allowClear;

  const _DotRatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.allowClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 5; i++)
                _Dot(
                  index: i,
                  selected: value == i,
                  filled: value != null && i <= value!,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (allowClear && value == i) {
                      onChanged(null);
                    } else {
                      onChanged(i);
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final int index;
  final bool selected;
  final bool filled;
  final VoidCallback onTap;

  const _Dot({
    required this.index,
    required this.selected,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = filled ? c.accent : c.hairline;

    return Semantics(
      button: true,
      selected: selected,
      label: '$index',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.reduced(context)
                  ? Duration.zero
                  : AppMotion.fast,
              width: selected ? 18 : 14,
              height: selected ? 18 : 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? color.withValues(alpha: selected ? 1 : 0.55)
                    : Colors.transparent,
                border: Border.all(
                  color: color,
                  width: selected ? 2 : 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.accent.withValues(alpha: 0.18) : c.surfaceSunken,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? c.accent : c.hairline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? c.accent : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
