import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/screens/home/home_calendar_section.dart';

/// The week strip reads its per-day totals out of a seven-slot list keyed by
/// position in the week. `table_calendar` hands its builders UTC-normalised
/// days, so the index has to come from calendar fields — an instant subtraction
/// against a local midnight is off by one in every zone west of Greenwich.
///
/// The tests below pin that without needing the host to be in a particular
/// zone: a local midnight in a UTC-5 zone *is* the instant 05:00Z, so passing
/// that instant as `monday` reproduces exactly the arithmetic the widget did.
void main() {
  group('weekDayIndex', () {
    test('maps a UTC-normalised day onto its slot in the week', () {
      final monday = DateTime(2026, 3, 2); // a Monday
      for (var i = 0; i < 7; i++) {
        expect(weekDayIndex(monday, DateTime.utc(2026, 3, 2 + i)), i);
      }
    });

    test('does not slip a slot when local midnight is behind UTC midnight', () {
      // 05:00Z is local midnight in a UTC-5 zone. The instant-subtraction the
      // widget used to do gives 19h for Tuesday, which floors to Monday's slot,
      // and Sunday's total is never read at all.
      final monday = DateTime.utc(2026, 3, 2, 5);
      for (var i = 0; i < 7; i++) {
        expect(
          weekDayIndex(monday, DateTime.utc(2026, 3, 2 + i)),
          i,
          reason: 'day ${2 + i} should sit in slot $i',
        );
      }
    });

    test('a day outside the week falls outside the seven slots', () {
      final monday = DateTime(2026, 3, 2);
      // The strip renders leading/trailing days from the neighbouring weeks;
      // they must miss the range rather than alias onto a real slot.
      expect(weekDayIndex(monday, DateTime.utc(2026, 3, 1)), -1);
      expect(weekDayIndex(monday, DateTime.utc(2026, 3, 9)), 7);
    });
  });
}
