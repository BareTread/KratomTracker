import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/date_utils.dart';
import '../domain/strain_usage.dart';
import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import 'add_strain_form.dart';
import 'dose_amount_control.dart';
import 'strain_mark.dart';
import 'undo_snack_bar.dart';

export 'dose_amount_control.dart' show parseDoseAmount, validateDoseAmount;

class AddDosageForm extends StatefulWidget {
  final String? preselectedStrainId;

  /// The day to log on. Null means the day Home is showing
  /// (`provider.selectedDate`); entry points with no day of their own, like
  /// a strain's "Log a dose", pass today so they don't inherit whatever day
  /// Home was last scrolled to.
  final DateTime? day;

  const AddDosageForm({
    super.key,
    this.preselectedStrainId,
    this.day,
  });

  @override
  State<AddDosageForm> createState() => _AddDosageFormState();
}

class _AddDosageFormState extends State<AddDosageForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _notesController = TextEditingController();
  late DateTime _openedAt;
  late DateTime _selectedDateTime;
  String? _selectedStrainId;
  bool _timeAdjusted = false;
  bool _notesOpen = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    final provider = context.read<KratomProvider>();
    _selectedDateTime = _seedDateTime(
      widget.day ?? provider.selectedDate,
      _openedAt,
    );
    _selectedStrainId = _preselect(
      provider.strainUsage,
      widget.preselectedStrainId,
    );
    final initial = _selectedStrainId == null
        ? ''
        : _prefillText(provider, _selectedStrainId!);
    _amountController = TextEditingController(text: initial);
    _notesOpen = _notesController.text.trim().isNotEmpty;
    _amountController.addListener(_onAmountEdited);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountEdited);
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onAmountEdited() {
    if (!mounted) return;
    setState(() {});
  }

  /// Seed from the calendar's selected day, keeping the frozen open-time
  /// time-of-day. If the selected day is today, use openedAt exactly.
  static DateTime _seedDateTime(DateTime selectedDate, DateTime openedAt) {
    final selectedDay = startOfDay(selectedDate);
    final openDay = startOfDay(openedAt);
    if (!selectedDay.isBefore(openDay)) return openedAt;
    return DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      openedAt.hour,
      openedAt.minute,
      openedAt.second,
      openedAt.millisecond,
    );
  }

  /// A given id wins. Otherwise the top in-stock suggestion is preselected,
  /// so the usual log is FAB -> Save. Calendar-rest ties are the common case
  /// in a 3-6 strain rotation, so a stricter "clear lead only" rule left the
  /// sheet empty most of the time; the Save label names the strain and the
  /// Undo snackbar is the backstop. Out-of-stock strains are never chosen.
  static String? _preselect(List<StrainUsage> usage, String? requestedId) {
    if (requestedId != null) {
      for (final item in usage) {
        if (item.strain.id == requestedId) return requestedId;
      }
      return null;
    }
    for (final item in usage) {
      if (item.strain.inStock) return item.strain.id;
    }
    return null;
  }

  static String _prefillText(KratomProvider provider, String strainId) {
    final recent = recentDoseAmounts(provider.dosages, strainId);
    if (recent.isNotEmpty) return formatDoseAmount(recent.first);
    for (final usage in provider.strainUsage) {
      if (usage.strain.id == strainId && usage.avgDoseSize > 0) {
        return formatDoseAmount(usage.avgDoseSize);
      }
    }
    return '';
  }

  bool get _showsNow =>
      !_timeAdjusted &&
      _selectedDateTime == _openedAt &&
      startOfDay(_selectedDateTime) == startOfDay(DateTime.now());

  String _chipLabel() {
    if (_showsNow) return 'Now';
    final now = DateTime.now();
    final time = DateFormat('h:mm a').format(_selectedDateTime);
    if (startOfDay(_selectedDateTime) == startOfDay(now)) {
      return 'Today, $time';
    }
    final day = _selectedDateTime.year == now.year
        ? DateFormat('MMM d').format(_selectedDateTime)
        : DateFormat('MMM d, y').format(_selectedDateTime);
    return '$day, $time';
  }

  Future<void> _pickStamp() async {
    final now = DateTime.now();
    final first = DateTime(2020);
    var initial = _selectedDateTime;
    if (initial.isAfter(now)) initial = now;
    if (initial.isBefore(first)) initial = first;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      _timeAdjusted = true;
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _snapToNow() {
    final now = DateTime.now();
    if (startOfDay(_selectedDateTime) == startOfDay(now)) {
      // On today, "Now" means now: back to the plain Now chip, pill gone.
      setState(() {
        _openedAt = now;
        _selectedDateTime = now;
        _timeAdjusted = false;
      });
      return;
    }
    // On a past day, keep the day and take the current clock time.
    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        now.hour,
        now.minute,
        now.second,
      );
    });
  }

  void _selectStrain(String id) {
    if (_selectedStrainId == id) return;
    _selectedStrainId = id;
    final next = _prefillText(context.read<KratomProvider>(), id);
    if (_amountController.text == next) {
      setState(() {});
      return;
    }
    _amountController.text = next;
  }

  String _saveLabel(String? code) {
    if (_saving) return 'Saving…';
    final raw = _amountController.text;
    final amount = parseDoseAmount(raw);
    if (code == null || amount == null || validateDoseAmount(raw) != null) {
      return 'Log dose';
    }
    return 'Log $code ${formatDoseAmount(amount)}g';
  }

  Future<void> _submit() async {
    if (_saving || _selectedStrainId == null) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = parseDoseAmount(_amountController.text);
    if (amount == null) return;

    if (_selectedDateTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dose time is in the future'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final notesRaw = _notesController.text.trim();
    final provider = context.read<KratomProvider>();
    final code = provider.getStrain(_selectedStrainId!)?.code ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    try {
      final created = await provider.addDosage(
        _selectedStrainId!,
        amount,
        _selectedDateTime,
        notes: notesRaw.isEmpty ? null : notesRaw,
      );
      unawaited(HapticFeedback.lightImpact());
      if (!mounted) return;
      navigator.pop();
      showUndoSnackBar(
        messenger,
        message: 'Logged $code · ${formatDoseAmount(amount)}g',
        onUndo: () async {
          try {
            await provider.deleteDosage(created.id);
          } on ArgumentError {
            // Already gone.
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save dose')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KratomProvider>();
    if (provider.strains.isEmpty) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.45,
        child: _buildEmptyStrainsState(),
      );
    }

    final c = context.c;
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final rawMax = media.size.height * 0.9 - inset;
    final maxHeight = rawMax < 0 ? 0.0 : rawMax;
    final usage = provider.strainUsage;
    final selected = _usageFor(usage, _selectedStrainId);
    final inStock = usage.where((u) => u.strain.inStock).toList(growable: false);
    final outOfStock =
        usage.where((u) => !u.strain.inStock).toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: c.surfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            primary: false,
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + media.padding.bottom),
            children: [
              Form(
                key: _formKey,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(c),
                  const SizedBox(height: 16),
                  _strainGrid(inStock, outOfStock),
                  const SizedBox(height: 12),
                  _selectedLine(c, provider, selected),
                  const SizedBox(height: 8),
                  DoseAmountControl(
                    controller: _amountController,
                    recentAmounts: selected == null
                        ? const []
                        : recentDoseAmounts(
                            provider.dosages,
                            selected.strain.id,
                          ),
                  ),
                  const SizedBox(height: 8),
                  _notes(c),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: c.accent.withValues(alpha: 0.38),
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        minimumSize: const Size(48, 48),
                        elevation: 0,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: selected == null || _saving ? null : _submit,
                      child: Text(
                        _saveLabel(selected?.strain.code),
                        style: const TextStyle(
                          fontFamily: AppType.sans,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppColors c) {
    final now = _showsNow;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Log dose',
          style: AppType.display(size: 30, color: c.textPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: _TimeChip(
                  label: _chipLabel(),
                  isNow: now,
                  onTap: _pickStamp,
                ),
              ),
              if (!now)
                TextButton(
                  key: const Key('add-dose-now-pill'),
                  onPressed: _snapToNow,
                  style: TextButton.styleFrom(
                    foregroundColor: c.accent,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Now',
                    style: TextStyle(fontFamily: AppType.sans, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _strainGrid(List<StrainUsage> inStock, List<StrainUsage> outOfStock) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Floor so three tiles plus two 8dp gaps cannot spill a row on
        // a binary rounding error.
        final tileWidth =
            ((constraints.maxWidth - 16) / 3).floorToDouble();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in inStock)
              _StrainTile(
                usage: item,
                width: tileWidth,
                selected: item.strain.id == _selectedStrainId,
                onTap: () => _selectStrain(item.strain.id),
              ),
            if (outOfStock.isNotEmpty)
              SizedBox(
                width: constraints.maxWidth,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: _StockDivider(),
                ),
              ),
            for (final item in outOfStock)
              _StrainTile(
                usage: item,
                width: tileWidth,
                selected: item.strain.id == _selectedStrainId,
                onTap: () => _selectStrain(item.strain.id),
              ),
          ],
        );
      },
    );
  }

  Widget _selectedLine(
    AppColors c,
    KratomProvider provider,
    StrainUsage? usage,
  ) {
    if (usage == null) {
      return SizedBox(
        height: 48,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Pick a strain',
            style: TextStyle(
              fontFamily: AppType.sans,
              fontSize: 13,
              color: c.textTertiary,
            ),
          ),
        ),
      );
    }

    final strain = usage.strain;
    final brightness = Theme.of(context).brightness;
    final leaf = legibleStrainColor(Color(strain.color), brightness);
    final name = strain.name.trim();
    final showName =
        name.isNotEmpty && name.toLowerCase() != strain.code.trim().toLowerCase();
    final load = usage.grams30d <= 0
        ? 'none this month'
        : '${_formatGrams(usage.grams30d)}g in 30d';
    final rest = showName ? ' · $name · $load' : ' · $load';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          StrainMark(
            shape: resolveLeafShape(strain.icon, strain.code),
            color: leaf,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            // Text.rich keeps the code out of the w600 Text finder that
            // reads tile order.
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 13,
                  color: c.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: strain.code,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: leaf,
                    ),
                  ),
                  TextSpan(text: rest),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!strain.inStock)
            TextButton(
              onPressed: () {
                unawaited(
                  provider.setStrainInStock(strain.id, inStock: true),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: c.accent,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Back in stock',
                style: TextStyle(fontFamily: AppType.sans, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notes(AppColors c) {
    if (!_notesOpen) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => _notesOpen = true),
          style: TextButton.styleFrom(
            foregroundColor: c.textSecondary,
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            alignment: Alignment.centerLeft,
          ),
          child: const Text(
            'Add note',
            style: TextStyle(fontFamily: AppType.sans, fontSize: 14),
          ),
        ),
      );
    }
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      style: TextStyle(fontFamily: AppType.sans, fontSize: 14, color: c.textPrimary),
      decoration: InputDecoration(
        labelText: 'Notes (optional)',
        alignLabelWithHint: true,
        labelStyle: TextStyle(fontFamily: AppType.sans, color: c.textSecondary),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyStrainsState() {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: c.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_florist_outlined,
                size: 48,
                color: c.accent.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Strains Added',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first strain to start tracking doses',
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const AddStrainForm(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Strain'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

StrainUsage? _usageFor(List<StrainUsage> usage, String? id) {
  if (id == null) return null;
  for (final item in usage) {
    if (item.strain.id == id) return item;
  }
  return null;
}

/// Tile rest. Rank < 3 and at least a day reads as rest; never-used is
/// `never` (the 365-day sentinel is not rest).
String _restLine(StrainUsage usage) {
  if (usage.lastUsed == null) return 'never';
  final days = usage.daysSinceLastUse.floor();
  if (usage.rank < 3 && usage.daysSinceLastUse >= 1) {
    return days == 1 ? 'rested 1d' : 'rested ${days}d';
  }
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 30) return '${days}d ago';
  final months = (days / 30).floor();
  if (months < 12) return '${months}mo ago';
  final years = (days / 365).floor();
  return years <= 1 ? '1y ago' : '${years}y ago';
}

String _formatGrams(double grams) {
  if (grams == grams.roundToDouble()) return grams.toStringAsFixed(0);
  final one = grams.toStringAsFixed(1);
  return one.endsWith('.0') ? one.substring(0, one.length - 2) : one;
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.isNow,
    required this.onTap,
  });

  final String label;
  final bool isNow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      key: const Key('add-dose-time-chip'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isNow ? null : Border.all(color: c.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppType.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isNow ? c.accent : c.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StockDivider extends StatelessWidget {
  const _StockDivider();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: c.hairline)),
        const SizedBox(width: 10),
        Text(
          'Out of stock',
          style: TextStyle(
            fontFamily: AppType.sans,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: c.textTertiary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: c.hairline)),
      ],
    );
  }
}

class _StrainTile extends StatelessWidget {
  const _StrainTile({
    required this.usage,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final StrainUsage usage;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final strain = usage.strain;
    final inStock = strain.inStock;
    final brightness = Theme.of(context).brightness;
    final leaf = legibleStrainColor(Color(strain.color), brightness);
    final rest = _restLine(usage);
    final borderColor = selected
        ? c.textPrimary
        : c.hairline.withValues(alpha: inStock ? 1 : 0.55);

    // 76 tall at the default font; a larger system font grows every tile in
    // the Wrap by the same amount, since each holds the same three lines.
    return ConstrainedBox(
      key: Key('dose-strain-${strain.id}'),
      constraints: BoxConstraints.tightFor(width: width).copyWith(
        minHeight: 76,
      ),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${strain.code}, $rest, ${inStock ? 'in stock' : 'out of stock'}',
        child: Material(
          color: selected ? c.surfaceSunken : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StrainMark(
                    shape: resolveLeafShape(strain.icon, strain.code),
                    color: leaf,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Opacity(
                    opacity: inStock ? 1 : 0.55,
                    child: Column(
                      children: [
                        Text(
                          strain.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppType.sans,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: leaf,
                          ),
                        ),
                        Text(
                          rest,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppType.sans,
                            fontSize: 11,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
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
