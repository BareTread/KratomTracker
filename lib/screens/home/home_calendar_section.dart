import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../theme/app_theme.dart';

class HomeCalendarSection extends StatelessWidget {
  const HomeCalendarSection({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
  });

  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;

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
    return Container(
      key: const Key('home-calendar-surface'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      decoration: BoxDecoration(
        color: context.c.surfaceRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.c.hairline),
      ),
      child: Column(
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
            rowHeight: 48,
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
              defaultBuilder: _semanticDay,
              todayBuilder: _semanticDay,
              selectedBuilder: _semanticDay,
              outsideBuilder: (context, day, focused) => _semanticDay(
                context,
                day,
                focused,
                enabled: false,
              ),
              disabledBuilder: (context, day, focused) => _semanticDay(
                context,
                day,
                focused,
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
      ),
    );
  }

  Widget _semanticDay(
    BuildContext context,
    DateTime day,
    DateTime focused, {
    bool enabled = true,
  }) {
    final selected = enabled && _sameDay(day, focusedDay);
    final today = _sameDay(day, DateTime.now());
    return Semantics(
      label:
          '${DateFormat.yMMMMEEEEd().format(day)}${selected ? ', selected' : ''}',
      button: true,
      enabled: enabled,
      selected: selected,
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? context.c.accent
                : today
                    ? context.c.accentMuted
                    : null,
            shape: BoxShape.circle,
            border: selected ? Border.all(color: context.c.textPrimary) : null,
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: enabled ? context.c.textPrimary : context.c.textTertiary,
              fontWeight: selected || today ? FontWeight.bold : null,
            ),
          ),
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
