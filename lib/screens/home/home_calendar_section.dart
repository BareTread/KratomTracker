import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../theme/app_theme.dart';

/// Calendar content (week strip + per-day grams bars + month picker) intended
/// to be embedded inside [HomeDayCard]. Owns no card chrome — the surrounding
/// card supplies the surface, border, and radius.
class HomeCalendarSection extends StatelessWidget {
  const HomeCalendarSection({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
    this.totalForDate,
  });

  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;

  /// Per-day grams totals used to draw the bars under each date. Defaults to
  /// zero so the widget renders standalone (e.g. in tests) without a provider.
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
    final monday = DateUtils.dateOnly(focusedDay)
        .subtract(Duration(days: focusedDay.weekday - 1));
    final weekTotals = List<double>.generate(
      7,
      (i) => totalFor(monday.add(Duration(days: i))),
    );
    final weekMax = weekTotals.fold<double>(0, (a, b) => a > b ? a : b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TableCalendar<void>(
          firstDay: DateTime.utc(2020),
          lastDay: today,
          focusedDay: focusedDay.isAfter(today) ? today : focusedDay,
          currentDay: today,
          calendarFormat: CalendarFormat.week,
          availableCalendarFormats: const {CalendarFormat.week: 'Week'},
          startingDayOfWeek: StartingDayOfWeek.monday,
          rowHeight: 58,
          daysOfWeekHeight: 24,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: context.c.textSecondary,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: context.c.textSecondary,
            ),
            headerPadding: const EdgeInsets.symmetric(vertical: 4),
          ),
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
            weekdayStyle: TextStyle(color: context.c.textTertiary),
            weekendStyle: TextStyle(color: context.c.textTertiary),
          ),
          calendarBuilders: CalendarBuilders<void>(
            headerTitleBuilder: (context, day) => Center(
              child: InkWell(
                onTap: () async {
                  final picked = await _showMonthPicker(context, day);
                  if (picked != null) _select(picked);
                },
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat.yMMMM().format(day),
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
            defaultBuilder: (context, day, focused) => _semanticDay(
              context,
              day,
              weekTotals: weekTotals,
              weekMax: weekMax,
              monday: monday,
              today: today,
            ),
            todayBuilder: (context, day, focused) => _semanticDay(
              context,
              day,
              weekTotals: weekTotals,
              weekMax: weekMax,
              monday: monday,
              today: today,
            ),
            selectedBuilder: (context, day, focused) => _semanticDay(
              context,
              day,
              weekTotals: weekTotals,
              weekMax: weekMax,
              monday: monday,
              today: today,
              enabled: true,
            ),
            outsideBuilder: (context, day, focused) => _semanticDay(
              context,
              day,
              weekTotals: weekTotals,
              weekMax: weekMax,
              monday: monday,
              today: today,
              enabled: false,
            ),
            disabledBuilder: (context, day, focused) => _semanticDay(
              context,
              day,
              weekTotals: weekTotals,
              weekMax: weekMax,
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
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                onToday
                    ? 'Today, ${DateFormat('d MMM').format(focusedDay)}'
                    : DateFormat('d MMM').format(focusedDay),
                style: TextStyle(
                  color: context.c.textSecondary,
                  fontSize: 14,
                ),
              ),
              if (!onToday) ...[
                const SizedBox(width: 8),
                _TodayButton(onTap: () => _select(today)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _semanticDay(
    BuildContext context,
    DateTime day, {
    required List<double> weekTotals,
    required double weekMax,
    required DateTime monday,
    required DateTime today,
    bool enabled = true,
  }) {
    final selected = enabled && _sameDay(day, focusedDay);
    final isToday = _sameDay(day, today);
    final dayIndex = day.difference(monday).inDays;
    final total = (dayIndex >= 0 && dayIndex < 7) ? weekTotals[dayIndex] : 0.0;
    final hasDoses = total > 0 && !day.isAfter(today);
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
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? context.c.accent
                    : isToday
                        ? context.c.accentMuted
                        : null,
                shape: BoxShape.circle,
                border:
                    selected ? Border.all(color: context.c.textPrimary) : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color:
                      enabled ? context.c.textPrimary : context.c.textTertiary,
                  fontWeight: selected || isToday ? FontWeight.bold : null,
                ),
              ),
            ),
            const SizedBox(height: 3),
            _DayBar(
              key: ValueKey('home-day-bar-${day.year}-${day.month}-${day.day}'),
              total: total,
              weekMax: weekMax,
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

/// A small bar under a calendar date whose height encodes that day's total
/// grams, scaled against the largest day in the visible week. Days with no
/// doses show a faint dot so the column still reads as a unit.
class _DayBar extends StatelessWidget {
  const _DayBar({
    super.key,
    required this.total,
    required this.weekMax,
    required this.hasDoses,
    required this.selected,
  });

  final double total;
  final double weekMax;
  final bool hasDoses;
  final bool selected;

  static const _maxHeight = 10.0;
  static const _minHeight = 3.0;

  @override
  Widget build(BuildContext context) {
    if (!hasDoses) {
      return Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: context.c.textTertiary.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
      );
    }
    final fraction = weekMax > 0 ? (total / weekMax).clamp(0.0, 1.0) : 0.0;
    final height = _minHeight + (_maxHeight - _minHeight) * fraction;
    return Container(
      width: 10,
      height: height,
      decoration: BoxDecoration(
        color: selected
            ? context.c.accent
            : context.c.textTertiary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Jump to today',
      child: Material(
        color: context.c.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.today, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
