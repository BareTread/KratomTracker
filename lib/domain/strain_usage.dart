import '../models/dosage.dart';
import '../models/strain.dart';
import 'date_utils.dart';

class StrainUsage {
  final Strain strain;
  final DateTime? lastUsed;
  final double daysSinceLastUse;
  final int dosesLastUsedDay;
  final double gramsLastUsedDay;
  final int doses7d;
  final double grams7d;
  final int doses30d;
  final double grams30d;
  final double avgDoseSize;
  final double rotationScore;
  final int rank;

  const StrainUsage({
    required this.strain,
    required this.lastUsed,
    required this.daysSinceLastUse,
    required this.dosesLastUsedDay,
    required this.gramsLastUsedDay,
    required this.doses7d,
    required this.grams7d,
    required this.doses30d,
    required this.grams30d,
    required this.avgDoseSize,
    required this.rotationScore,
    required this.rank,
  });
}

List<StrainUsage> computeStrainUsage(
  List<Strain> strains,
  List<Dosage> dosages, {
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final range7d = lastNDays(7, now: effectiveNow);
  final range30d = lastNDays(30, now: effectiveNow);
  final provisional = <StrainUsage>[];

  for (final strain in strains) {
    final strainDoses = dosages
        .where((dose) => dose.strainId == strain.id)
        .toList(growable: false);
    DateTime? lastUsed;
    for (final dose in strainDoses) {
      if (lastUsed == null || dose.timestamp.isAfter(lastUsed)) {
        lastUsed = dose.timestamp;
      }
    }

    final dosesOnLastDay = lastUsed == null
        ? const <Dosage>[]
        : strainDoses
            .where((dose) => _sameDay(dose.timestamp, lastUsed!))
            .toList(growable: false);
    final last7d = strainDoses
        .where((dose) =>
            inRangeInclusive(dose.timestamp, range7d.start, range7d.end))
        .toList(growable: false);
    final last30d = strainDoses
        .where((dose) =>
            inRangeInclusive(dose.timestamp, range30d.start, range30d.end))
        .toList(growable: false);
    final grams30d = _sum(last30d);

    // This formula is intentionally frozen to preserve the app's rotation order.
    final daysSinceUse = lastUsed == null
        ? 365.0
        : effectiveNow.difference(lastUsed).inDays.toDouble();
    final consumptionScore = 1.0 - (grams30d / 500.0).clamp(0.0, 1.0);
    final rotationScore = (daysSinceUse * 0.7) + (consumptionScore * 100 * 0.3);

    provisional.add(
      StrainUsage(
        strain: strain,
        lastUsed: lastUsed,
        daysSinceLastUse: daysSinceUse,
        dosesLastUsedDay: dosesOnLastDay.length,
        gramsLastUsedDay: _sum(dosesOnLastDay),
        doses7d: last7d.length,
        grams7d: _sum(last7d),
        doses30d: last30d.length,
        grams30d: grams30d,
        avgDoseSize: last30d.isEmpty ? 0 : grams30d / last30d.length,
        rotationScore: rotationScore,
        rank: 0,
      ),
    );
  }

  provisional.sort((a, b) {
    final byScore = b.rotationScore.compareTo(a.rotationScore);
    return byScore != 0 ? byScore : a.strain.code.compareTo(b.strain.code);
  });

  return [
    for (var i = 0; i < provisional.length; i++)
      StrainUsage(
        strain: provisional[i].strain,
        lastUsed: provisional[i].lastUsed,
        daysSinceLastUse: provisional[i].daysSinceLastUse,
        dosesLastUsedDay: provisional[i].dosesLastUsedDay,
        gramsLastUsedDay: provisional[i].gramsLastUsedDay,
        doses7d: provisional[i].doses7d,
        grams7d: provisional[i].grams7d,
        doses30d: provisional[i].doses30d,
        grams30d: provisional[i].grams30d,
        avgDoseSize: provisional[i].avgDoseSize,
        rotationScore: provisional[i].rotationScore,
        rank: i,
      ),
  ];
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

double _sum(Iterable<Dosage> dosages) =>
    dosages.fold(0, (total, dosage) => total + dosage.amount);
