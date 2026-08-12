import '../models/dosage.dart';
import '../models/strain.dart';
import 'date_utils.dart';

class StrainUsage {
  final Strain strain;
  final DateTime? lastUsed;

  /// Whole calendar days since the last dose, not elapsed 24h periods: a dose
  /// at 23:00 yesterday reads as 1, never as 0.
  final double daysSinceLastUse;
  final int doses30d;
  final double grams30d;

  /// This strain's share of all grams logged in the last 30 days, expressed as
  /// a multiple of an even split. 1.0 means it carried exactly its fair share
  /// of the rotation, 3.0 means three times that.
  final double concentration;

  /// [grams30d] as a fraction of the busiest strain's, for the row's load bar.
  final double relativeLoad;
  final double avgDoseSize;
  final double rotationScore;
  final int rank;

  const StrainUsage({
    required this.strain,
    required this.lastUsed,
    required this.daysSinceLastUse,
    required this.doses30d,
    required this.grams30d,
    required this.concentration,
    required this.relativeLoad,
    required this.avgDoseSize,
    required this.rotationScore,
    required this.rank,
  });
}

/// Ranks strains for the picker: the most rested come first, but a strain the
/// rotation has been leaning on has to rest longer to earn the same place.
///
/// The old formula scored consumption against a hardcoded 500g ceiling. At a
/// real month's intake that term barely moved, so the order read as "days since
/// last use, with unexplained jitter". [concentration] replaces it with a
/// scale-free measure — a strain's share of the month relative to an even split
/// — which means the ranking behaves the same whether the shelf holds six
/// strains or sixty, and whether the month totalled 100g or 400g.
List<StrainUsage> computeStrainUsage(
  List<Strain> strains,
  List<Dosage> dosages, {
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final range30d = lastNDays(30, now: effectiveNow);
  final raw = <_RawUsage>[];

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

    final last30d = strainDoses
        .where(
          (dose) =>
              inRangeInclusive(dose.timestamp, range30d.start, range30d.end),
        )
        .toList(growable: false);

    raw.add(
      _RawUsage(
        strain: strain,
        lastUsed: lastUsed,
        // Calendar days, so an evening dose still reads as "yesterday" the
        // next morning instead of collapsing to "today".
        daysSinceUse: lastUsed == null
            ? 365.0
            : daysBetween(lastUsed, effectiveNow).toDouble(),
        doses30d: last30d.length,
        grams30d: _sum(last30d),
      ),
    );
  }

  final totalGrams30d = raw.fold<double>(0, (sum, r) => sum + r.grams30d);
  final maxGrams30d =
      raw.fold<double>(0, (best, r) => r.grams30d > best ? r.grams30d : best);
  final evenShare = raw.isEmpty ? 0.0 : totalGrams30d / raw.length;

  final provisional = [
    for (final r in raw) _score(r, evenShare: evenShare, maxGrams: maxGrams30d),
  ]..sort((a, b) {
      final byScore = b.rotationScore.compareTo(a.rotationScore);
      return byScore != 0 ? byScore : a.strain.code.compareTo(b.strain.code);
    });

  return [
    for (var i = 0; i < provisional.length; i++) _withRank(provisional[i], i),
  ];
}

class _RawUsage {
  final Strain strain;
  final DateTime? lastUsed;
  final double daysSinceUse;
  final int doses30d;
  final double grams30d;

  const _RawUsage({
    required this.strain,
    required this.lastUsed,
    required this.daysSinceUse,
    required this.doses30d,
    required this.grams30d,
  });
}

StrainUsage _score(
  _RawUsage r, {
  required double evenShare,
  required double maxGrams,
}) {
  final concentration = evenShare <= 0 ? 0.0 : r.grams30d / evenShare;

  // Rest divided by load. The +1 keeps a strain used today from collapsing to
  // zero — among equally fresh strains the lighter-used one should still come
  // first — and the +0.5 keeps an untouched strain's score large but finite.
  final rotationScore = (r.daysSinceUse + 1) / (0.5 + concentration);

  return StrainUsage(
    strain: r.strain,
    lastUsed: r.lastUsed,
    daysSinceLastUse: r.daysSinceUse,
    doses30d: r.doses30d,
    grams30d: r.grams30d,
    concentration: concentration,
    relativeLoad: maxGrams <= 0 ? 0 : r.grams30d / maxGrams,
    avgDoseSize: r.doses30d == 0 ? 0 : r.grams30d / r.doses30d,
    rotationScore: rotationScore,
    rank: 0,
  );
}

StrainUsage _withRank(StrainUsage u, int rank) => StrainUsage(
      strain: u.strain,
      lastUsed: u.lastUsed,
      daysSinceLastUse: u.daysSinceLastUse,
      doses30d: u.doses30d,
      grams30d: u.grams30d,
      concentration: u.concentration,
      relativeLoad: u.relativeLoad,
      avgDoseSize: u.avgDoseSize,
      rotationScore: u.rotationScore,
      rank: rank,
    );

double _sum(Iterable<Dosage> dosages) =>
    dosages.fold(0, (total, dosage) => total + dosage.amount);
