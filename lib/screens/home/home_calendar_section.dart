import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../domain/date_utils.dart';
import '../../providers/kratom_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/day_sprig.dart';

/// Which slot of the Monday-first week strip [day] belongs to.
///
/// `table_calendar` hands its builders **UTC-normalised** days while [monday]
/// is a local midnight, so the obvious `day.difference(monday).inDays` mixes
/// two zones and truncates. West of Greenwich the difference for the n-th day
/// is `n days - offset hours`, which floors to `n - 1`: every square read the
/// previous day's total and Sunday's was never read at all. [day] is a
/// calendar label, not an instant, so it is rebuilt as one and counted in
/// calendar days — which is also exact across a DST transition.
int weekDayIndex(DateTime monday, DateTime day) =>
    daysBetween(monday, DateTime(day.year, day.month, day.day));

/// Compare calendar labels without interpreting UTC-normalised labels as instants.
int compareCalendarDays(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day)
        .compareTo(DateTime.utc(b.year, b.month, b.day));

/// Calendar content (week strip + per-day dose dots + month picker).
/// Owns no card chrome. The chevron glyph and the week grid share the
/// section's left edge, so the day card can line that up with the status text.
class HomeCalendarSection extends StatelessWidget {
  const HomeCalendarSection({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
    this.totalForDate,
  });

  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;

  /// Per-day grams totals used to decide whether a day has doses (presence
  /// dot). Defaults to zero so the widget renders standalone without a
  /// provider.
  final double Function(DateTime date)? totalForDate;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _select(DateTime day) {
    HapticFeedback.selectionClick();
    onDaySelected(day);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final onToday = _sameDay(focusedDay, today);
    final totalFor = totalForDate ?? (_) => 0.0;
    // Calendar days throughout, never elapsed hours: Duration(days: n) is
    // exactly 24h, so a week spanning a DST transition lands a day short or
    // long — the same class of bug date_utils exists to stop.
    final monday = addDays(focusedDay, -(focusedDay.weekday - 1));
    final weekTotals = List<double>.generate(
      7,
      (i) => totalFor(addDays(monday, i)),
    );
    final sprigs = _weekSprigs(context, monday);
    final canGoForward = addDays(focusedDay, 7).isBefore(addDays(today, 1));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Left padding is 0 so this row and the week grid share the section
        // edge. The chevron's 8px icon inset is shifted back out so the glyph,
        // not the hit slop, sits on that edge. Hit-box size is unchanged.
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 8, 0),
          child: Row(
            children: [
              Transform.translate(
                offset: const Offset(-8, 0),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final prev = addDays(focusedDay, -7);
                    _select(
                      prev.isBefore(DateTime(2020)) ? DateTime(2020) : prev,
                    );
                  },
                  icon: Icon(
                    Icons.chevron_left,
                    color: context.c.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () async {
                      final picked =
                          await _showMonthPicker(context, focusedDay);
                      if (picked != null) _select(picked);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 36),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              DateFormat.yMMMM().format(focusedDay),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.c.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: context.c.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: canGoForward
                    ? () {
                        final next = addDays(focusedDay, 7);
                        _select(next.isAfter(today) ? today : next);
                      }
                    : null,
                icon: Icon(
                  Icons.chevron_right,
                  color: canGoForward
                      ? context.c.textSecondary
                      : context.c.textTertiary.withValues(alpha: 0.4),
                ),
              ),
              if (!onToday)
                _TodayButton(onTap: () => _select(today))
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
        // Fixed 32px day discs and a 20px weekday row: past 1.5x the
        // numbers wrap ("2" over "5") and the labels clip.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: TableCalendar<void>(
            firstDay: DateTime.utc(2020),
            lastDay: today,
            // Clamped both ways: the pager itself reaches back past 2020.
            focusedDay: focusedDay.isAfter(today)
                ? today
                : focusedDay.isBefore(DateTime(2020))
                    ? DateTime(2020)
                    : focusedDay,
            currentDay: today,
            calendarFormat: CalendarFormat.week,
            availableCalendarFormats: const {CalendarFormat.week: 'Week'},
            startingDayOfWeek: StartingDayOfWeek.monday,
            // 32 date disc + 2 + a 28px micro-sprig, with 2px to spare.
            rowHeight: 64,
            daysOfWeekHeight: 20,
            headerVisible: false,
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: context.c.textPrimary),
              weekendTextStyle: TextStyle(color: context.c.textPrimary),
              outsideTextStyle: TextStyle(color: context.c.textTertiary),
              disabledTextStyle: TextStyle(color: context.c.textTertiary),
              todayDecoration: BoxDecoration(
                color: context.c.accentMuted,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: context.c.textPrimary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: Theme.of(context).scaffoldBackgroundColor,
                fontFamily: AppType.sans,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: context.c.textTertiary,
                fontSize: 12,
              ),
              weekendStyle: TextStyle(
                color: context.c.textTertiary,
                fontSize: 12,
              ),
            ),
            calendarBuilders: CalendarBuilders<void>(
              defaultBuilder: (context, day, focused) => _semanticDay(
                context,
                day,
                weekTotals: weekTotals,
                sprigs: sprigs,
                monday: monday,
                today: today,
              ),
              todayBuilder: (context, day, focused) => _semanticDay(
                context,
                day,
                weekTotals: weekTotals,
                sprigs: sprigs,
                monday: monday,
                today: today,
              ),
              selectedBuilder: (context, day, focused) => _semanticDay(
                context,
                day,
                weekTotals: weekTotals,
                sprigs: sprigs,
                monday: monday,
                today: today,
                enabled: true,
              ),
              outsideBuilder: (context, day, focused) => _semanticDay(
                context,
                day,
                weekTotals: weekTotals,
                sprigs: sprigs,
                monday: monday,
                today: today,
                enabled: false,
              ),
              disabledBuilder: (context, day, focused) => _semanticDay(
                context,
                day,
                weekTotals: weekTotals,
                sprigs: sprigs,
                monday: monday,
                today: today,
                enabled: false,
              ),
            ),
            onDaySelected: (day, _) {
              // TableCalendar passes UTC midnights; startOfDay would convert
              // them with toLocal() and land on the previous day west of UTC.
              final local = DateTime(day.year, day.month, day.day);
              if (!_sameDay(local, focusedDay) &&
                  compareCalendarDays(local, today) <= 0) {
                _select(local);
              }
            },
            selectedDayPredicate: (day) => _sameDay(focusedDay, day),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _semanticDay(
    BuildContext context,
    DateTime day, {
    required List<double> weekTotals,
    required _WeekSprigs? sprigs,
    required DateTime monday,
    required DateTime today,
    bool enabled = true,
  }) {
    final selected = enabled && _sameDay(day, focusedDay);
    final isToday = _sameDay(day, today);
    final dayIndex = weekDayIndex(monday, day);
    final total = (dayIndex >= 0 && dayIndex < 7) ? weekTotals[dayIndex] : 0.0;
    final hasDoses = total > 0 && compareCalendarDays(day, today) <= 0;
    // Today → cyan (filled when selected, ring + numeral otherwise).
    // Selected and not today → ink disc, page-coloured numeral.
    // Has doses → 3×3 presence dot under the number.
    final page = Theme.of(context).scaffoldBackgroundColor;
    final Color textColor;
    final Color? fill;
    final Border? ring;
    if (!enabled) {
      textColor = context.c.textTertiary;
      fill = null;
      ring = null;
    } else if (selected && isToday) {
      textColor = page;
      fill = context.c.accent;
      ring = null;
    } else if (selected) {
      textColor = page;
      fill = context.c.textPrimary;
      ring = null;
    } else if (isToday) {
      textColor = context.c.accent;
      fill = null;
      ring = Border.all(color: context.c.accent, width: 1.5);
    } else {
      textColor = context.c.textPrimary;
      fill = null;
      ring = null;
    }
    return Semantics(
      label:
          '${DateFormat.yMMMMEEEEd().format(day)}${selected ? ', selected' : ''}',
      button: true,
      enabled: enabled,
      selected: selected,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              // The fill travels with the selection instead of snapping.
              duration:
                  AppMotion.reduced(context) ? Duration.zero : AppMotion.fast,
              curve: AppMotion.emphasized,
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill ?? Colors.transparent,
                shape: BoxShape.circle,
                border: ring,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontFamily: AppType.sans,
                  color: textColor,
                  fontWeight:
                      selected || isToday ? FontWeight.w600 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 2),
            if (sprigs != null && dayIndex >= 0 && dayIndex < 7)
              _MicroSprig(
                key: ValueKey(
                  'home-day-bar-${day.year}-${day.month}-${day.day}',
                ),
                doses: sprigs.doses[dayIndex],
                scale: sprigs.scale,
                // Nothing before the record starts or after today; today
                // is still growing, so an empty today is not a rest day.
                visible: compareCalendarDays(day, today) <= 0 &&
                    sprigs.first != null &&
                    compareCalendarDays(day, sprigs.first!) >= 0,
                rest: !isToday,
              )
            else
              _DayDot(
                key: ValueKey(
                  'home-day-bar-${day.year}-${day.month}-${day.day}',
                ),
                hasDoses: hasDoses,
                selected: selected,
              ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _showMonthPicker(
    BuildContext context,
    DateTime initialDate,
  ) {
    var month = DateTime(initialDate.year, initialDate.month);
    final today = DateUtils.dateOnly(DateTime.now());
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final locale = Localizations.localeOf(dialogContext).toString();
          final firstDayIndex =
              MaterialLocalizations.of(dialogContext).firstDayOfWeekIndex;
          final first = DateTime(month.year, month.month);
          final leading = ((first.weekday % 7) - firstDayIndex + 7) % 7;
          final days = DateTime(month.year, month.month + 1, 0).day;
          return Dialog(
            backgroundColor: dialogContext.c.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        // The week strip starts at 2020; a month before it
                        // would hand TableCalendar a day before its firstDay.
                        onPressed: DateTime(month.year, month.month - 1)
                                .isBefore(DateTime(2020))
                            ? null
                            : () => setDialogState(() {
                                  month = DateTime(month.year, month.month - 1);
                                }),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          DateFormat.yMMMM(locale).format(month),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: DateTime(month.year, month.month + 1)
                                .isAfter(DateTime(today.year, today.month))
                            ? null
                            : () => setDialogState(() {
                                  month = DateTime(month.year, month.month + 1);
                                }),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Row(
                    children: List.generate(7, (index) {
                      final weekday =
                          DateTime(2024, 1, 7 + firstDayIndex + index);
                      return Expanded(
                        child: Text(
                          DateFormat.E(locale).format(weekday),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: dialogContext.c.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisExtent: 48,
                    ),
                    itemCount: leading + days,
                    itemBuilder: (_, index) {
                      if (index < leading) return const SizedBox.shrink();
                      final day = index - leading + 1;
                      final date = DateTime(month.year, month.month, day);
                      final selected = _sameDay(date, focusedDay);
                      final isToday = _sameDay(date, today);
                      final enabled = !date.isAfter(today);
                      final page =
                          Theme.of(dialogContext).scaffoldBackgroundColor;
                      return Semantics(
                        label: DateFormat.yMMMMEEEEd(locale).format(date),
                        button: true,
                        enabled: enabled,
                        selected: selected,
                        child: InkWell(
                          onTap: enabled
                              ? () => Navigator.pop(dialogContext, date)
                              : null,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            alignment: Alignment.center,
                            decoration: !enabled
                                ? null
                                : selected && isToday
                                    ? BoxDecoration(
                                        color: dialogContext.c.accent,
                                        shape: BoxShape.circle,
                                      )
                                    : selected
                                        ? BoxDecoration(
                                            color: dialogContext.c.textPrimary,
                                            shape: BoxShape.circle,
                                          )
                                        : isToday
                                            ? BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: dialogContext.c.accent,
                                                  width: 1.5,
                                                ),
                                              )
                                            : null,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontFamily: AppType.sans,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: !enabled
                                    ? dialogContext.c.textTertiary
                                    : selected
                                        ? page
                                        : isToday
                                            ? dialogContext.c.accent
                                            : dialogContext.c.textPrimary,
                                fontWeight: selected ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

typedef _WeekSprigs = ({
  List<List<SprigDose>> doses,
  double scale,
  DateTime? first,
});

/// The week's doses for the micro-sprigs, on one gram scale for the week.
/// Read from the provider here rather than passed in, so the Home card keeps
/// its signature; with no provider (standalone widget tests) this is null and
/// the strip falls back to the presence dot.
_WeekSprigs? _weekSprigs(BuildContext context, DateTime monday) {
  final KratomProvider provider;
  try {
    provider = Provider.of<KratomProvider>(context);
  } on ProviderNotFoundException {
    return null;
  }
  final fallback = context.c.textTertiary;
  final doses = [
    for (var i = 0; i < 7; i++)
      [
        for (final dose in provider.getDosagesForDate(addDays(monday, i)))
          SprigDose.fromDosage(
            dose,
            switch (provider.getStrain(dose.strainId)) {
              final strain? => Color(strain.color),
              null => fallback,
            },
          ),
      ],
  ];
  DateTime? first;
  for (final dose in provider.dosages) {
    final day = startOfDay(dose.timestamp);
    if (first == null || day.isBefore(first)) first = day;
  }
  return (doses: doses, scale: sprigScaleFor(doses), first: first);
}

/// A day's doses as a 20×28 sprig under its date number: a leaf per dose at
/// its time of day, length in grams on the week's scale, a bud on a rest day.
/// Always reserves its slot so the week row stays level.
class _MicroSprig extends StatelessWidget {
  const _MicroSprig({
    super.key,
    required this.doses,
    required this.scale,
    required this.visible,
    required this.rest,
  });

  static const size = Size(20, 28);

  final List<SprigDose> doses;
  final double scale;
  final bool visible;
  final bool rest;

  @override
  Widget build(BuildContext context) {
    if (!visible) return SizedBox.fromSize(size: size);
    return DaySprig(
      doses: doses,
      scaleGrams: scale,
      rest: rest,
      size: size,
    );
  }
}

/// 3×3 presence dot under a calendar day number. Visible only when the day
/// has doses. On the selected day the dot is scaffold-coloured at half
/// opacity so it still reads against the filled accent circle above.
class _DayDot extends StatelessWidget {
  const _DayDot({
    super.key,
    required this.hasDoses,
    required this.selected,
  });

  final bool hasDoses;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // Reserve the same 3px slot whether or not a dose exists so the week
    // row height stays uniform.
    if (!hasDoses) {
      return const SizedBox(width: 3, height: 3);
    }
    final color = selected
        ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5)
        : context.c.textTertiary.withValues(alpha: 0.7);
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Accent-tinted pill, shown only when the selected day is not today.
class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Jump to today',
      child: Material(
        key: const Key('home-today-pill'),
        color: context.c.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  'Today',
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
