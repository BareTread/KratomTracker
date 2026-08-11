import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/kratom_provider.dart';
import '../theme/app_theme.dart';
import '../domain/strain_usage.dart';
import '../widgets/add_strain_form.dart';
import 'strain_usage_tile.dart';

class AddDosageForm extends StatefulWidget {
  final String? preselectedStrainId;

  const AddDosageForm({
    super.key,
    this.preselectedStrainId,
  });

  @override
  State<AddDosageForm> createState() => _AddDosageFormState();
}

class _AddDosageFormState extends State<AddDosageForm> {
  bool _strainSelected = false;
  late String? _selectedStrainId;
  bool _forward = true;

  /// Wall-clock moment the Add Dose flow opened. Frozen for the whole sheet
  /// lifetime so a delayed save still records the intent time, not save time.
  late final DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _selectedStrainId = widget.preselectedStrainId;
    if (_selectedStrainId != null) {
      _strainSelected = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KratomProvider>();
    final strains = provider.strains;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    if (strains.isEmpty) {
      return SizedBox(
        height: maxHeight * 0.5,
        child: _buildEmptyStrainsState(),
      );
    }

    final reduced = AppMotion.reduced(context);
    final duration = reduced ? Duration.zero : AppMotion.normal;

    return SizedBox(
      height: maxHeight,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AppMotion.emphasized,
        switchOutCurve: AppMotion.emphasized,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final offset = _forward
              ? Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(animation)
              : Tween<Offset>(
                  begin: const Offset(-0.06, 0),
                  end: Offset.zero,
                ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: _strainSelected
            ? _DosageDetailsForm(
                key: const ValueKey('details'),
                strainId: _selectedStrainId!,
                openedAt: _openedAt,
                onBack: () {
                  setState(() {
                    _forward = false;
                    _strainSelected = false;
                  });
                },
              )
            : _StrainSelectionView(
                key: const ValueKey('select'),
                onStrainSelected: (strainId) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _forward = true;
                    _selectedStrainId = strainId;
                    _strainSelected = true;
                  });
                },
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

// Step 1: Strain Selection — order is provider.strainUsage (frozen).
// Stock partition is applied after the frozen ranking; relative order inside
// each group is preserved.
class _StrainSelectionView extends StatelessWidget {
  final ValueChanged<String> onStrainSelected;

  const _StrainSelectionView({
    super.key,
    required this.onStrainSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Consumer<KratomProvider>(
      builder: (context, provider, child) {
        final usage = provider.strainUsage;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Text(
                  'Select Strain',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: _buildList(c, provider, usage),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    AppColors c,
    KratomProvider provider,
    List<StrainUsage> usage,
  ) {
    // Stock is a partition applied AFTER the frozen ranking: in-stock strains
    // keep their relative order, then out-of-stock ones keep theirs.
    final inStockItems =
        usage.where((u) => u.strain.inStock).toList(growable: false);
    final outOfStockItems =
        usage.where((u) => !u.strain.inStock).toList(growable: false);
    final hasOutOfStock = outOfStockItems.isNotEmpty;

    if (!hasOutOfStock) {
      // Day-one state: every strain in stock — no divider, no header, no
      // visual change from the pre-stock picker.
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: inStockItems.length,
        itemBuilder: (context, index) {
          final item = inStockItems[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _StaggeredEntrance(
              index: index,
              child: StrainUsageTile(
                usage: item,
                onTap: () => onStrainSelected(item.strain.id),
              ),
            ),
          );
        },
      );
    }

    final totalCount = inStockItems.length + 1 + outOfStockItems.length;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < inStockItems.length) {
          final item = inStockItems[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _StaggeredEntrance(
              index: index,
              child: StrainUsageTile(
                usage: item,
                onTap: () => onStrainSelected(item.strain.id),
              ),
            ),
          );
        }
        if (index == inStockItems.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: _StockDivider(),
          );
        }
        final outIndex = index - inStockItems.length - 1;
        final item = outOfStockItems[outIndex];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _StaggeredEntrance(
            index: index,
            child: StrainUsageTile(
              usage: item,
              inStock: false,
              onTap: () => onStrainSelected(item.strain.id),
              onToggleStock: () => provider.setStrainInStock(
                item.strain.id,
                inStock: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredEntrance({
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;

    final staggerMs = (index * 20).clamp(0, 200);
    final totalMs = AppMotion.normal.inMilliseconds + staggerMs;
    final start = staggerMs / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(start, 1, curve: AppMotion.emphasized),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(10 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: child,
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
        Expanded(
          child: Container(height: 1, color: c.hairline),
        ),
        const SizedBox(width: 10),
        Text(
          'Out of stock',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: c.textTertiary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: c.hairline),
        ),
      ],
    );
  }
}

class _DosageDetailsForm extends StatefulWidget {
  final String strainId;
  final DateTime openedAt;
  final VoidCallback onBack;

  const _DosageDetailsForm({
    super.key,
    required this.strainId,
    required this.openedAt,
    required this.onBack,
  });

  @override
  State<_DosageDetailsForm> createState() => _DosageDetailsFormState();
}

class _DosageDetailsFormState extends State<_DosageDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _selectedDateTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<KratomProvider>(context, listen: false);
    _selectedDateTime = _seedDateTime(provider.selectedDate, widget.openedAt);
    _prefillAmount(provider);
  }

  /// Seed from the calendar's selected day, keeping the frozen open-time
  /// time-of-day. If the selected day is today, use openedAt exactly.
  static DateTime _seedDateTime(DateTime selectedDate, DateTime openedAt) {
    final selectedDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final openDay = DateTime(openedAt.year, openedAt.month, openedAt.day);
    if (selectedDay == openDay) return openedAt;
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

  /// Prefill amount with the strain's usual dose (30-day average), falling
  /// back to the most recent dose for that strain if the average is zero.
  void _prefillAmount(KratomProvider provider) {
    StrainUsage? usage;
    for (final u in provider.strainUsage) {
      if (u.strain.id == widget.strainId) {
        usage = u;
        break;
      }
    }

    double? usual;
    if (usage != null && usage.avgDoseSize > 0) {
      usual = usage.avgDoseSize;
    } else {
      // Most recent dose for this strain, if any.
      final doses = provider.dosages
          .where((d) => d.strainId == widget.strainId)
          .toList(growable: false);
      if (doses.isNotEmpty) {
        doses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        usual = doses.first.amount;
      }
    }

    if (usual != null && usual > 0) {
      _amountController.text = _formatAmount(usual);
    }
  }

  static String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    final one = amount.toStringAsFixed(1);
    return one.endsWith('.0') ? one.substring(0, one.length - 2) : one;
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  void _snapToNow() {
    final now = DateTime.now();
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

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = parseDoseAmount(_amountController.text);
    if (amount == null) return;

    final notesRaw = _notesController.text.trim();
    final notes = notesRaw.isEmpty ? null : notesRaw;

    final provider = context.read<KratomProvider>();
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    try {
      await provider.addDosage(
        widget.strainId,
        amount,
        _selectedDateTime,
        notes: notes,
      );
      await HapticFeedback.lightImpact();

      if (!mounted) return;
      navigator.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save dose')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack,
                    ),
                    Text(
                      'Add Dose',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      _inputDecoration(context, label: 'Amount', suffix: 'g'),
                  validator: validateDoseAmount,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateTimeButton(
                        icon: Icons.calendar_today,
                        label:
                            DateFormat('MMM d, y').format(_selectedDateTime),
                        onPressed: () => _selectDate(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateTimeButton(
                        icon: Icons.access_time,
                        label:
                            DateFormat('h:mm a').format(_selectedDateTime),
                        onPressed: () => _selectTime(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _NowPill(onTap: _snapToNow),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    context,
                    label: 'Notes (optional)',
                    alignHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _saving ? null : _submit,
                  child: Text(
                    _saving ? 'Saving…' : 'Add Dose',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final c = context.c;
    return Material(
      color: c.surfaceSunken,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: c.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: c.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14, color: c.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    String? suffix,
    bool alignHint = false,
  }) {
    final c = context.c;
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      alignLabelWithHint: alignHint,
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
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

/// Small cyan "Now" pill mirroring the home calendar's "Today" control.
class _NowPill extends StatelessWidget {
  final VoidCallback onTap;

  const _NowPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Set time to now',
      child: Material(
        key: const Key('add-dose-now-pill'),
        color: context.c.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  'Now',
                  style: TextStyle(
                    color: context.c.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

/// Shared amount parsing: trim, accept `,` or `.` as decimal separator.
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
  if (amount == null) {
    return 'Please enter a valid number';
  }
  if (!amount.isFinite) {
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
