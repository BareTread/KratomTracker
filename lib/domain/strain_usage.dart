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

/// Ranks strains for the Add Dose picker by rotation rest.
///
/// Calendar days since last dose is the only primary key: a strain last taken
/// 5 days ago always ranks ahead of one taken 2 days ago, even if it carried
/// far more of the month. Never-used strains are treated as the most rested.
/// 30-day grams break ties only inside the same rest bucket, lighter first;
/// equal rest and equal volume fall back to strain code, then strain ID,
/// so the order is a total deterministic order.
/// Future timestamps clamp to "today" so corrupt clocks cannot invert the list.
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
        // next morning instead of collapsing to "today". A future/corrupt
        // timestamp is treated as today rather than a negative rest.
        daysSinceUse: lastUsed == null
            ? 365.0
            : _nonNegativeDays(lastUsed, effectiveNow),
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
      final aNever = a.lastUsed == null;
      final bNever = b.lastUsed == null;
      if (aNever != bNever) return aNever ? -1 : 1;

      final byRest = b.daysSinceLastUse.compareTo(a.daysSinceLastUse);
      if (byRest != 0) return byRest;

      final byVolume = a.grams30d.compareTo(b.grams30d);
      if (byVolume != 0) return byVolume;

      final byCode = a.strain.code.compareTo(b.strain.code);
      if (byCode != 0) return byCode;

      return a.strain.id.compareTo(b.strain.id);
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

  // Recency only. Volume is applied in the sort, never mixed into this score,
  // so a heavier 5-day rest cannot lose to a lighter 2-day rest.
  final rotationScore = r.daysSinceUse;

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

double _nonNegativeDays(DateTime lastUsed, DateTime now) {
  final elapsed = daysBetween(lastUsed, now);
  return (elapsed < 0 ? 0 : elapsed).toDouble();
}
