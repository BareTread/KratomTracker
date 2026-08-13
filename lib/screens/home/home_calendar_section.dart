import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../domain/date_utils.dart';
import '../../theme/app_theme.dart';

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

/// Calendar content (week strip + per-day dose dots + month picker) intended
/// to live inside its own card. Owns no card chrome — the surrounding card
/// supplies the surface, border, and radius.
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
    final canGoForward = addDays(focusedDay, 7).isBefore(addDays(today, 1));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final prev = addDays(focusedDay, -7);
                  _select(
                    prev.isBefore(DateTime.utc(2020))
                        ? DateTime.utc(2020)
                        : prev,
                  );
                },
                icon: Icon(
                  Icons.chevron_left,
                  color: context.c.accent,
                ),
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () async {
                      final picked = await _showMonthPicker(context, focusedDay);
                      if (picked != null) _select(picked);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat.yMMMM().format(focusedDay),
                            style: TextStyle(
                              color: context.c.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: context.c.accent,
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
                      ? context.c.accent
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
        TableCalendar<void>(
          firstDay: DateTime.utc(2020),
          lastDay: today,
          focusedDay: focusedDay.isAfter(today) ? today : focusedDay,
          currentDay: today,
          calendarFormat: CalendarFormat.week,
          availableCalendarFormats: const {CalendarFormat.week: 'Week'},
          startingDayOfWeek: StartingDayOfWeek.monday,
          rowHeight: 58,
          daysOfWeekHeight: 22,
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
              color: context.c.accent,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(color: context.c.textPrimary),
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
              monday: monday,
              today: today,
            ),
            todayBuilder: (context, day, focused) => _semanticDay(
              context,
              day,
              weekTotals: weekTotals,
              monday: monday,
              today: today,
            ),
            selectedBuilder: (context, day, focused) => _semanticDay(
              context,
              day,
              weekTotals: weekTotals,
              monday: monday,
              today: today,
              enabled: true,
            ),
            outsideBuilder: (context, day, focused) => _semanticDay(
              context,
              day,
              weekTotals: weekTotals,
              monday: monday,
              today: today,
              enabled: false,
            ),
            disabledBuilder: (context, day, focused) => _semanticDay(
              context,
              day,
              weekTotals: weekTotals,
              monday: monday,
              today: today,
              enabled: false,
            ),
          ),
          onDaySelected: (day, _) {
            if (!_sameDay(day, focusedDay) && !day.isAfter(today)) {
              _select(day);
            }
          },
          selectedDayPredicate: (day) => _sameDay(focusedDay, day),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _semanticDay(
    BuildContext context,
    DateTime day, {
    required List<double> weekTotals,
    required DateTime monday,
    required DateTime today,
    bool enabled = true,
  }) {
    final selected = enabled && _sameDay(day, focusedDay);
    final isToday = _sameDay(day, today);
    final dayIndex = weekDayIndex(monday, day);
    final total = (dayIndex >= 0 && dayIndex < 7) ? weekTotals[dayIndex] : 0.0;
    final hasDoses = total > 0 && !day.isAfter(today);
    // Selected → filled accent circle, scaffold-coloured text.
    // Today (not selected) → 1.5px inset accent ring, accent text.
    // Has doses → 3×3 presence dot under the number.
    final Color textColor;
    if (!enabled) {
      textColor = context.c.textTertiary;
    } else if (selected) {
      textColor = Theme.of(context).scaffoldBackgroundColor;
    } else if (isToday) {
      textColor = context.c.accent;
    } else {
      textColor = context.c.textPrimary;
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
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? context.c.accent : null,
                shape: BoxShape.circle,
                border: isToday && !selected
                    ? Border.all(
                        color: context.c.accent,
                        width: 1.5,
                      )
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: selected
                      ? FontWeight.w600
                      : isToday
                          ? FontWeight.w600
                          : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 3),
            _DayDot(
              key: ValueKey('home-day-bar-${day.year}-${day.month}-${day.day}'),
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
                        onPressed: () => setDialogState(() {
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
                      final enabled = !date.isAfter(today);
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
                            decoration: selected
                                ? BoxDecoration(
                                    color: dialogContext.c.accent,
                                    shape: BoxShape.circle,
                                  )
                                : null,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: enabled
                                    ? dialogContext.c.textPrimary
                                    : dialogContext.c.textTertiary,
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
