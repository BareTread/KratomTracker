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

/// The log-a-dose sheet: a strain ledger that scrolls, over a pinned footer
/// holding everything else a log needs (amount, when, Log), so nothing that
/// finishes the job sits below the fold however many strains are stocked.
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

/// Quick "it was a little while ago" choices, measured back from the moment
/// they are tapped. They replace each other; they never stack.
const _agoChoices = [Duration(minutes: 30), Duration(hours: 1)];

class _AddDosageFormState extends State<AddDosageForm> {
  final _formKey = GlobalKey<FormState>();
  final _selectedRowKey = GlobalKey();
  late final TextEditingController _amountController;
  final _notesController = TextEditingController();

  /// The moment the sheet opened. An untouched "Now" logs this, not the save
  /// time: the owner logs right after a dose, so opening is the better proxy.
  late final DateTime _openedAt;

  /// The dose's calendar day (local midnight).
  late DateTime _day;

  /// The clock time picked or implied by an "ago" choice. Null is "Now" on
  /// an automatic day, and "not set yet" on a day the user named.
  TimeOfDay? _time;

  /// The day was named: picked in the date picker, or inherited from a past
  /// Home page. An automatic day follows the time (today, or yesterday for a
  /// time that has not come yet today).
  bool _dayNamed = false;

  /// The "ago" choice in force, if any; cleared by any other time change.
  Duration? _ago;

  /// The exact instant the "ago" choice stands for (tap time minus the
  /// offset), so seconds and a repeated DST hour survive to the save.
  DateTime? _agoAt;

  /// Rebuilds now and then while a picked time could cross "now" or a
  /// midnight with the sheet left open, so the caution and labels keep up.
  Timer? _clockTick;

  /// A picked time was later than now on an automatic day, so the dose moved
  /// to yesterday. Said out loud under the When row.
  bool _rolledBack = false;

  String? _selectedStrainId;
  bool _showOutOfStock = false;
  bool _notesOpen = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    final provider = context.read<KratomProvider>();
    final base = startOfDay(widget.day ?? provider.selectedDate);
    final today = startOfDay(_openedAt);
    if (base.isBefore(today)) {
      // A past Home page: keep its day, but ask for the time rather than
      // borrowing today's clock, which says nothing about that dose.
      _day = base;
      _dayNamed = true;
    } else {
      _day = today;
    }
    _selectedStrainId = _preselect(
      provider.strainUsage,
      widget.preselectedStrainId,
    );
    final preselected = _usageFor(provider.strainUsage, _selectedStrainId);
    // Open on the Out shelf when the launch names an out-of-stock strain, or
    // when nothing is in stock at all.
    _showOutOfStock = (preselected != null && !preselected.strain.inStock) ||
        provider.strainUsage.every((u) => !u.strain.inStock);
    final initial = _selectedStrainId == null
        ? ''
        : _prefillText(provider, _selectedStrainId!);
    _amountController = TextEditingController(text: initial);
    _amountController.addListener(_onAmountEdited);
    if (_selectedStrainId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
    _clockTick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_isNow) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTick?.cancel();
    _amountController.removeListener(_onAmountEdited);
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onAmountEdited() {
    if (!mounted) return;
    setState(() {});
  }

  /// Only a launch that names a strain selects one. From the FAB nothing is
  /// chosen: rotation rank is a hint for the owner, not evidence of what
  /// they took, and a wrong guess saves no taps while leaving a wrong save
  /// one tap away.
  static String? _preselect(List<StrainUsage> usage, String? requestedId) {
    if (requestedId == null) return null;
    for (final item in usage) {
      if (item.strain.id == requestedId) return requestedId;
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

  void _revealSelected() {
    final ctx = _selectedRowKey.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(ctx, alignment: 0.3);
  }

  // ---------------------------------------------------------------- when

  bool get _isNow => _time == null && !_dayNamed;

  /// What gets saved. Null while a named day still needs its time.
  DateTime? get _stamp {
    if (_isNow) return _openedAt;
    if (_ago != null) return _agoAt;
    final t = _time;
    if (t == null) return null;
    return DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);
  }

  bool get _stampInFuture {
    final stamp = _stamp;
    return stamp != null && stamp.isAfter(DateTime.now());
  }

  String _dayLabel(DateTime day) {
    final today = startOfDay(DateTime.now());
    final d = startOfDay(day);
    if (d == today) return 'Today';
    if (d == addDays(today, -1)) return 'Yesterday';
    return d.year == today.year
        ? DateFormat('EEE, MMM d').format(d)
        : DateFormat('MMM d, y').format(d);
  }

  String _timeLabel(TimeOfDay t) => MaterialLocalizations.of(context)
      .formatTimeOfDay(
        t,
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  /// The date chip names the day the dose will land on. For an untouched
  /// "Now" that is the opening day, which reads "Yesterday" if the sheet sat
  /// open past midnight.
  String get _dateChipLabel => _dayLabel(_isNow ? _openedAt : _day);

  /// Always a clock time (the lit "Now" beside it says when it is live), or
  /// "Set time" on a named day still waiting for one.
  String get _timeChipLabel {
    if (_isNow) return _timeLabel(TimeOfDay.fromDateTime(_openedAt));
    final t = _time;
    return t == null ? 'Set time' : _timeLabel(t);
  }

  Future<void> _pickDate() async {
    if (_saving) return;
    final now = DateTime.now();
    final first = DateTime(2020);
    var initial = _isNow ? startOfDay(_openedAt) : _day;
    if (initial.isAfter(now)) initial = startOfDay(now);
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    final day = startOfDay(picked);
    setState(() {
      _ago = null;
      _agoAt = null;
      _rolledBack = false;
      if (day == startOfDay(_openedAt) && _time == null) {
        // Back to the opening day with no time chosen: plain Now again.
        // Any other day, even a new "today" after midnight, needs a time.
        _day = day;
        _dayNamed = false;
        return;
      }
      _day = day;
      _dayNamed = true;
    });
    // A day picked with no time yet goes straight on to the time: the one
    // case where the two pickers belong together.
    if (_time == null && _dayNamed && mounted) await _pickTime();
  }

  Future<void> _pickTime() async {
    if (_saving) return;
    final seed = _time ??
        TimeOfDay.fromDateTime(_isNow ? _openedAt : DateTime.now());
    final picked = await showTimePicker(context: context, initialTime: seed);
    if (picked == null || !mounted) return;
    setState(() {
      _ago = null;
      _agoAt = null;
      _time = picked;
      if (_dayNamed) {
        _rolledBack = false;
        return;
      }
      final day = dayForPickedTime(picked, now: DateTime.now());
      _day = day.day;
      _rolledBack = day.rolledBack;
    });
  }

  void _setNow() {
    if (_saving) return;
    setState(() {
      _ago = null;
      _agoAt = null;
      _time = null;
      _dayNamed = false;
      _rolledBack = false;
      _day = startOfDay(_openedAt);
    });
  }

  void _setAgo(Duration ago) {
    if (_saving) return;
    if (_ago == ago) {
      _setNow();
      return;
    }
    final at = DateTime.now().subtract(ago);
    setState(() {
      _ago = ago;
      _agoAt = at;
      _time = TimeOfDay.fromDateTime(at);
      _day = startOfDay(at);
      _dayNamed = false;
      _rolledBack = false;
    });
  }

  // -------------------------------------------------------------- strain

  void _selectStrain(String id) {
    if (_saving || _selectedStrainId == id) return;
    unawaited(HapticFeedback.selectionClick());
    _selectedStrainId = id;
    final next = _prefillText(context.read<KratomProvider>(), id);
    if (_amountController.text == next) {
      setState(() {});
      return;
    }
    _amountController.text = next;
  }

  // ---------------------------------------------------------------- save

  String _saveLabel(String? code) {
    if (_saving) return 'Saving…';
    if (code == null) return 'Pick a strain';
    if (_stamp == null) return 'Set time';
    final raw = _amountController.text;
    final amount = parseDoseAmount(raw);
    if (amount == null || validateDoseAmount(raw) != null) {
      return 'Log $code';
    }
    return 'Log $code ${formatDoseAmount(amount)}g';
  }

  /// "Logged RB · 16.5g", plus the day and time whenever it is not now, so a
  /// dose that landed on another day is named before the Undo runs out.
  String _loggedMessage(String code, double amount, DateTime stamp) {
    final base = 'Logged $code · ${formatDoseAmount(amount)}g';
    if (_isNow) return base;
    final time = _timeLabel(TimeOfDay.fromDateTime(stamp));
    final when = switch (_dayLabel(stamp)) {
      'Today' => time,
      'Yesterday' => 'yesterday $time',
      final day => '$day, $time',
    };
    return '$base · $when';
  }

  Future<void> _submit() async {
    if (_saving || _selectedStrainId == null) return;
    if (_stamp == null) {
      await _pickTime();
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final amount = parseDoseAmount(_amountController.text);
    if (amount == null) return;

    final stamp = _stamp!;
    if (stamp.isAfter(DateTime.now())) {
      setState(() {});
      return;
    }

    final notesRaw = _notesController.text.trim();
    final provider = context.read<KratomProvider>();
    final code = provider.getStrain(_selectedStrainId!)?.code ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final message = _loggedMessage(code, amount, stamp);

    setState(() => _saving = true);
    try {
      final created = await provider.addDosage(
        _selectedStrainId!,
        amount,
        stamp,
        notes: notesRaw.isEmpty ? null : notesRaw,
      );
      unawaited(HapticFeedback.lightImpact());
      if (!mounted) return;
      navigator.pop();
      showUndoSnackBar(
        messenger,
        message: message,
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

  // --------------------------------------------------------------- build

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
    final groups = _StrainGroups.of(usage);
    // The Out shelf closes itself once its last strain is restocked.
    final showOut = _showOutOfStock && groups.outOfStock.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: c.surfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, box) {
                // The footer keeps its natural height unless the sheet is
                // squeezed (keyboard plus a large font); then it scrolls on
                // its own rather than overflow, leaving the ledger a strip.
                final footerMax = (box.maxHeight * 0.62).clamp(0.0, 640.0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(c, groups, showOut),
                    Flexible(child: _ledger(c, groups, showOut)),
                    Container(height: 1, color: c.hairline),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: footerMax),
                      child: SingleChildScrollView(
                        primary: false,
                        child: _footer(c, provider, selected, media),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppColors c, _StrainGroups groups, bool showOut) {
    final hasOut = groups.outOfStock.isNotEmpty;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    'Log dose',
                    style: AppType.display(size: 30, color: c.textPrimary),
                  ),
                ),
                if (hasOut)
                  _StockSwitch(
                    outCount: groups.outOfStock.length,
                    showingOut: showOut,
                    onChanged: (out) => setState(() => _showOutOfStock = out),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  Spacer(),
                  _ColumnLabel('Last', width: _StrainRow.lastWidth),
                  _ColumnLabel('30 days', width: _StrainRow.gramsWidth),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _ledger(AppColors c, _StrainGroups groups, bool showOut) {
    final rows = <Widget>[];
    void addRows(List<StrainUsage> items, {required bool dim}) {
      for (final item in items) {
        final isSelected = item.strain.id == _selectedStrainId;
        rows.add(
          _StrainRow(
            key: Key('dose-strain-${item.strain.id}'),
            anchorKey: isSelected ? _selectedRowKey : null,
            usage: item,
            selected: isSelected,
            dim: dim,
            onTap: () => _selectStrain(item.strain.id),
          ),
        );
      }
    }

    if (showOut) {
      addRows(groups.outOfStock, dim: true);
    } else {
      addRows(groups.rotation, dim: false);
      if (groups.resting.isNotEmpty) {
        rows.add(
          const _GroupDivider(
            key: Key('add-dose-resting-divider'),
            label: 'Not taken in 30 days',
          ),
        );
        addRows(groups.resting, dim: false);
      }
      if (rows.isEmpty) {
        rows.add(_emptyInStock(c));
      }
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: ListView(
        // A fresh list per shelf, so switching starts at its top.
        key: ValueKey(showOut),
        primary: false,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: rows,
      ),
    );
  }

  Widget _emptyInStock(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Text(
        'Nothing in stock. The Out tab lists the rest.',
        style: TextStyle(
          fontFamily: AppType.sans,
          fontSize: 13,
          color: c.textTertiary,
        ),
      ),
    );
  }

  Widget _footer(
    AppColors c,
    KratomProvider provider,
    StrainUsage? selected,
    MediaQueryData media,
  ) {
    final future = _stampInFuture;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 14 + media.padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selected != null && !selected.strain.inStock)
            _outOfStockNote(c, provider, selected),
          DoseAmountControl(
            controller: _amountController,
            recentAmounts: const [],
          ),
          const SizedBox(height: 10),
          _whenRow(c),
          if (_rolledBack && !future)
            _Notice(
              key: const Key('add-dose-rolled-back'),
              icon: Icons.history,
              color: c.textSecondary,
              text: '${_timeLabel(_time!)} was still ahead, so this goes '
                  'on ${_rolledDayWords()}',
            ),
          if (future)
            _Notice(
              key: const Key('add-dose-future'),
              icon: Icons.schedule,
              color: c.caution,
              text: 'That time is still ahead. Pick an earlier one.',
            ),
          if (_notesOpen) ...[
            const SizedBox(height: 10),
            _notesField(c),
          ],
          const SizedBox(height: 8),
          _actions(c, selected, future),
        ],
      ),
    );
  }

  Widget _outOfStockNote(
    AppColors c,
    KratomProvider provider,
    StrainUsage usage,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${usage.strain.code} is out of stock',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppType.sans,
              fontSize: 13,
              color: c.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: _saving ? null : () => _restock(provider, usage),
          style: TextButton.styleFrom(
            foregroundColor: c.accent,
            minimumSize: const Size(48, 40),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Back in stock',
            style: TextStyle(fontFamily: AppType.sans, fontSize: 13),
          ),
        ),
      ],
    );
  }

  /// The stored day in words for the roll-back notice: "yesterday" in the
  /// usual case, the date once the sheet has sat open past another midnight.
  String _rolledDayWords() {
    final label = _dayLabel(_day);
    return label == 'Yesterday' ? 'yesterday' : label;
  }

  Future<void> _restock(KratomProvider provider, StrainUsage usage) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.setStrainInStock(usage.strain.id, inStock: true);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update stock')),
      );
      return;
    }
    if (!mounted) return;
    // Follow the strain to its new shelf so the selection stays in view.
    setState(() => _showOutOfStock = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  Widget _whenRow(AppColors c) {
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _WhenChip(
          key: const Key('add-dose-date-chip'),
          icon: Icons.calendar_today_outlined,
          label: _dateChipLabel,
          emphasised: _rolledBack,
          semanticsLabel: 'Date, $_dateChipLabel',
          onTap: _pickDate,
        ),
        _WhenChip(
          key: const Key('add-dose-time-chip'),
          icon: Icons.schedule,
          label: _timeChipLabel,
          emphasised: !_isNow && _time == null,
          semanticsLabel: 'Time, $_timeChipLabel',
          onTap: _pickTime,
        ),
        _AgoGroup(
          isNow: _isNow,
          active: _ago,
          onNow: _setNow,
          onAgo: _setAgo,
        ),
      ],
    );
  }

  Widget _actions(AppColors c, StrainUsage? selected, bool future) {
    final ready = selected != null && !_saving && !future;
    // With a large system font the Log label needs the room more than the
    // words "Add note" do: the note button keeps its icon and tooltip.
    final roomy = MediaQuery.textScalerOf(context).scale(10) <= 11.5;
    void openNotes() => setState(() => _notesOpen = true);
    return Row(
      children: [
        if (!_notesOpen && roomy)
          TextButton.icon(
            key: const Key('add-dose-note'),
            onPressed: openNotes,
            icon: const Icon(Icons.notes, size: 18),
            label: const Text(
              'Add note',
              style: TextStyle(fontFamily: AppType.sans, fontSize: 14),
            ),
            style: TextButton.styleFrom(
              foregroundColor: c.textSecondary,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.only(right: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        if (!_notesOpen && !roomy)
          IconButton(
            key: const Key('add-dose-note'),
            tooltip: 'Add note',
            onPressed: openNotes,
            icon: const Icon(Icons.notes),
            color: c.textSecondary,
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              key: const Key('add-dose-save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: c.accent.withValues(alpha: 0.38),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                minimumSize: const Size(48, 52),
                elevation: 0,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: ready ? _submit : null,
              child: Text(
                _saveLabel(selected?.strain.code),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notesField(AppColors c) {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      minLines: 1,
      autofocus: true,
      style: TextStyle(
        fontFamily: AppType.sans,
        fontSize: 14,
        color: c.textPrimary,
      ),
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

/// The day a time picked without naming a day lands on: today, or yesterday
/// when that time has not come yet today (a dose can't be logged ahead).
/// The sheet says so in the date chip and a notice line, and the Undo bar
/// names the day.
@visibleForTesting
({DateTime day, bool rolledBack}) dayForPickedTime(
  TimeOfDay picked, {
  required DateTime now,
}) {
  final today = startOfDay(now);
  final candidate = DateTime(
    today.year,
    today.month,
    today.day,
    picked.hour,
    picked.minute,
  );
  // Minute precision: the current minute itself is "now", not ahead.
  final nowMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  final ahead = candidate.isAfter(nowMinute);
  return (day: ahead ? addDays(today, -1) : today, rolledBack: ahead);
}

StrainUsage? _usageFor(List<StrainUsage> usage, String? id) {
  if (id == null) return null;
  for (final item in usage) {
    if (item.strain.id == id) return item;
  }
  return null;
}

/// The ledger's three shelves, cut from `provider.strainUsage`.
///
/// * rotation: in stock with a dose in the last 30 days, in the provider's
///   order (most rested first, lighter month first on a tie);
/// * resting: in stock, nothing in 30 days. Most recently used first, so a
///   strain coming back into rotation sits near the top; never used last
///   (the provider ranks never-used as most rested, which here would bury
///   the comebacks under strains nobody has tried);
/// * outOfStock: the same recency order, shown only on request.
class _StrainGroups {
  const _StrainGroups(this.rotation, this.resting, this.outOfStock);

  final List<StrainUsage> rotation;
  final List<StrainUsage> resting;
  final List<StrainUsage> outOfStock;

  static _StrainGroups of(List<StrainUsage> usage) {
    final rotation = <StrainUsage>[];
    final resting = <StrainUsage>[];
    final out = <StrainUsage>[];
    for (final item in usage) {
      if (!item.strain.inStock) {
        out.add(item);
      } else if (item.doses30d > 0) {
        rotation.add(item);
      } else {
        resting.add(item);
      }
    }
    return _StrainGroups(
      rotation,
      _byRecency(resting),
      _byRecency(out),
    );
  }

  static List<StrainUsage> _byRecency(List<StrainUsage> items) {
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
    indexed.sort((a, b) {
      final aLast = a.$2.lastUsed;
      final bLast = b.$2.lastUsed;
      if (aLast == null || bLast == null) {
        if (aLast == bLast) return a.$1.compareTo(b.$1);
        return aLast == null ? 1 : -1;
      }
      final byTime = bLast.compareTo(aLast);
      if (byTime != 0) return byTime;
      return a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }
}

/// "today", "yesterday", "3d ago", "2mo ago", "never".
String _lastLabel(StrainUsage usage) {
  if (usage.lastUsed == null) return 'never';
  final days = usage.daysSinceLastUse.floor();
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 30) return '${days}d ago';
  final months = (days / 30).floor();
  if (months < 12) return '${months}mo ago';
  final years = (days / 365).floor();
  return years <= 1 ? '1y ago' : '${years}y ago';
}

String _gramsLabel(double grams) {
  if (grams <= 0) return '–';
  if (grams == grams.roundToDouble()) return '${grams.toStringAsFixed(0)}g';
  final one = grams.toStringAsFixed(1);
  return '${one.endsWith('.0') ? one.substring(0, one.length - 2) : one}g';
}

/// One ledger line: mark, code, name, then the two facts a pick is made on,
/// in fixed right-aligned columns so they compare straight down the list.
class _StrainRow extends StatelessWidget {
  const _StrainRow({
    super.key,
    this.anchorKey,
    required this.usage,
    required this.selected,
    required this.dim,
    required this.onTap,
  });

  static const double lastWidth = 76;
  static const double gramsWidth = 64;

  final Key? anchorKey;
  final StrainUsage usage;
  final bool selected;
  final bool dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final strain = usage.strain;
    final brightness = Theme.of(context).brightness;
    final leaf = legibleStrainColor(Color(strain.color), brightness);
    final name = strain.name.trim();
    final showName =
        name.isNotEmpty && name.toLowerCase() != strain.code.trim().toLowerCase();
    final last = _lastLabel(usage);
    final grams = _gramsLabel(usage.grams30d);
    final scaler = MediaQuery.textScalerOf(context);
    const tabular = [FontFeature.tabularFigures()];
    final figureStyle = TextStyle(
      fontFamily: AppType.sans,
      fontSize: 13,
      color: c.textSecondary,
      fontFeatures: tabular,
    );
    final semantics = StringBuffer(strain.code);
    if (showName) semantics.write(', $name');
    semantics.write(
      usage.lastUsed == null ? ', never taken' : ', last taken $last',
    );
    semantics.write(
      usage.grams30d > 0 ? ', $grams in 30 days' : ', none in 30 days',
    );
    if (!strain.inStock) semantics.write(', out of stock');

    return Padding(
      key: anchorKey,
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: semantics.toString(),
        excludeSemantics: true,
        child: Material(
          color: selected ? c.surfaceSunken : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: selected
                ? BorderSide(color: c.textPrimary, width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                child: Opacity(
                  opacity: dim ? 0.6 : 1,
                  child: Row(
                    children: [
                      StrainMark(
                        shape: resolveLeafShape(strain.icon, strain.code),
                        color: leaf,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          strain.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppType.sans,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: leaf,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          showName ? name : '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppType.sans,
                            fontSize: 13,
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: scaler.scale(lastWidth),
                        child: Text(
                          last,
                          maxLines: 1,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: figureStyle,
                        ),
                      ),
                      SizedBox(
                        width: scaler.scale(gramsWidth),
                        child: Text(
                          grams,
                          maxLines: 1,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: figureStyle.copyWith(
                            color: usage.grams30d > 0
                                ? c.textPrimary
                                : c.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.text, {required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: MediaQuery.textScalerOf(context).scale(width),
      child: Text(
        text.toUpperCase(),
        textAlign: TextAlign.end,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: AppType.eyebrow(c.textTertiary).copyWith(
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppType.eyebrow(c.textTertiary).copyWith(
              fontSize: 10,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: c.hairline)),
        ],
      ),
    );
  }
}

/// In stock / Out of stock, as two quiet tabs. Out of stock is a separate
/// shelf rather than the tail of the list, so back-logging a finished strain
/// is one tap, not a scroll past every stocked one.
class _StockSwitch extends StatelessWidget {
  const _StockSwitch({
    required this.outCount,
    required this.showingOut,
    required this.onChanged,
  });

  final int outCount;
  final bool showingOut;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget tab(String label, bool active, bool out, Key key) {
      return Semantics(
        button: true,
        selected: active,
        child: InkWell(
          key: key,
          onTap: active ? null : () => onChanged(out),
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? c.surfaceSunken : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? c.textPrimary : c.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tab('In stock', !showingOut, false, const Key('add-dose-in-stock')),
          tab(
            'Out · $outCount',
            showingOut,
            true,
            const Key('add-dose-out-of-stock'),
          ),
        ],
      ),
    );
  }
}

/// A hairline chip with an icon: the date and time controls. Each opens its
/// own picker, so a time change never goes through the calendar.
class _WhenChip extends StatelessWidget {
  const _WhenChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.semanticsLabel,
    this.emphasised = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String semanticsLabel;

  /// Drawn in the accent: a day that moved, or a time still to be set.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ink = emphasised ? c.accent : c.textPrimary;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: emphasised ? c.accent : c.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: emphasised ? c.accent : c.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppType.sans,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
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

/// Now · −30m · −1h. One is lit while it is in force; picking a time or a
/// day by hand lights none.
class _AgoGroup extends StatelessWidget {
  const _AgoGroup({
    required this.isNow,
    required this.active,
    required this.onNow,
    required this.onAgo,
  });

  final bool isNow;
  final Duration? active;
  final VoidCallback onNow;
  final ValueChanged<Duration> onAgo;

  static String _short(Duration d) =>
      d.inMinutes < 60 ? '−${d.inMinutes}m' : '−${d.inHours}h';

  static String _spoken(Duration d) => d.inMinutes < 60
      ? '${d.inMinutes} minutes ago'
      : d.inHours == 1
          ? '1 hour ago'
          : '${d.inHours} hours ago';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget option({
      required Key key,
      required String label,
      required String spoken,
      required bool on,
      required VoidCallback onTap,
    }) {
      return Semantics(
        button: true,
        selected: on,
        label: spoken,
        excludeSemantics: true,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 40),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? c.surfaceSunken : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                  color: on ? c.accent : c.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        option(
          key: const Key('add-dose-now'),
          label: 'Now',
          spoken: 'Now',
          on: isNow,
          onTap: onNow,
        ),
        for (final ago in _agoChoices)
          option(
            key: Key('add-dose-ago-${ago.inMinutes}'),
            label: _short(ago),
            spoken: _spoken(ago),
            on: active == ago,
            onTap: () => onAgo(ago),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppType.sans,
                fontSize: 12.5,
                height: 1.3,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
