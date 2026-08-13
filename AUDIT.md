# Audit of Herbal Tracker+ @ v2.16.0 — **INCOMPLETE / HANDOFF**

> **Status: this audit was cut short mid-run.** One Tier 1 fix is committed and
> verified. The rest of the Tier 1 list is specified below but *not implemented*.
> Findings recorded here were reached by reading and, where marked **verified**,
> by executing code. Findings marked **unverified** are reasoned but not yet
> proven — a following agent should prove or drop each one before acting on it.
> See [Handoff](#handoff--what-is-left) at the bottom.

## Verdict (provisional)

The domain layer is in genuinely good shape. `analytics_service.dart` and
`insights_service.dart` are careful, the null-below-threshold discipline is
applied consistently, and the *why* comments are load-bearing rather than
decorative. I re-derived Theil–Sen, the trailing median, `G = F × A`, the
inverse-Herfindahl breadth, the median-of-daily-medians spacing and the episode
collapsing in the return cycle, and found no arithmetic errors in any of them.
Every domain read site localises its timestamps before touching a date, hour or
weekday, exactly as `date_utils.dart` demands.

The defects found are all **outside** `lib/domain/` — in the presentation and
export layers, which localise inconsistently and do calendar arithmetic in
elapsed hours. That is the same class of bug `date_utils.dart` was written to
kill; it just was never applied past the domain boundary.

I did not manufacture findings to fill space. The list below is short because
the code is good.

---

## Findings

### 1. Week strip read the previous day's total in every zone west of UTC — **FIXED, verified**

`lib/screens/home/home_calendar_section.dart:223` (pre-fix)

`table_calendar` hands its builders **UTC-normalised** days; `monday` was a
**local** midnight. `day.difference(monday).inDays` subtracted two zones and
truncated.

Failure scenario (executed, `TZ=America/New_York`, week of Mon 2 Mar 2026):

```
day 2 -> index 0 (expected 0)
day 3 -> index 0 (expected 1)   <-- Tuesday shows Monday's dot
day 4 -> index 1 (expected 2)
day 5 -> index 2 (expected 3)
day 6 -> index 3 (expected 4)
day 7 -> index 4 (expected 5)
day 8 -> index 5 (expected 6)   <-- Sunday's total never read
```

So a user in New York who dosed on Monday and rested Tuesday saw the presence
dot under Tuesday, not Monday, for every day of every week. UTC and zones east
of it are correct by accident, which is why 207 tests and the owner's own
Europe/London device never surfaced it.

**Confidence: certain** — reproduced by execution, both before and after.
Fixed in commit `7c5ea09`, with a regression test that reproduces the arithmetic
zone-independently (a local midnight in a UTC−5 zone *is* the instant `05:00Z`).
The same commit moves the strip's other week arithmetic off `Duration(days:)`,
which is not DST-exact.

### 2. History screen groups and displays imported doses on the wrong day — **unverified, high confidence**

`lib/screens/report_screen.dart:202-204`, `:176`, `:287`

```dart
final date = DateTime(
  dosage.timestamp.year,     // <-- UTC fields if the dose came from a 1.0 import
  dosage.timestamp.month,
  dosage.timestamp.day,
);
```

This is precisely the pattern the doc comment at the top of `date_utils.dart`
names as wrong. Every other read site in the app calls `startOfDay()`, which
localises first; these three do not.

Failure scenario: a dose imported from a 1.0 backup carrying
`2024-06-05T23:30:00.000Z`. In Europe/London (BST, UTC+1) the user took it at
00:30 on **6 June**. `stats_screen` counts it on 6 June (via `startOfDay`); the
Dosage history screen files it under **5 June** and labels it **11:30 PM**. The
two screens disagree about the same dose, and the disagreement is invisible
unless you look at both.

**Fix (Tier 1, one line each):** `startOfDay(dosage.timestamp)` for the
grouping; `.toLocal()` before each `DateFormat(...).format(...)`. `toLocal()` is
a no-op on an already-local `DateTime`, so live data is unaffected.

### 3. CSV export writes UTC clock time for imported doses — **unverified, high confidence**

`lib/export/csv_export.dart:42-43`

```dart
DateFormat('yyyy-MM-dd').format(dose.timestamp),
DateFormat('HH:mm').format(dose.timestamp),
```

`intl`'s `DateFormat.format` reads the `DateTime`'s fields as-is; it does not
localise. Same input as finding 2 exports as `2024-06-05,23:30` while the app
shows it on 6 June at 00:30. The adjacent `iso_timestamp` column is correct
(it keeps the `Z`), so the export is internally inconsistent as well.

**Fix (Tier 1):** `.toLocal()` on both, leave `iso_timestamp` alone.

### 4. Home timeline shows UTC clock time for imported doses — **unverified, high confidence**

`lib/screens/home/home_dosage_list.dart:241-242`

Same mechanism as finding 3, on the screen the user looks at most.

**Fix (Tier 1):** `.toLocal()` on both.

### 5. A single bad timestamp can make the stats screen hang or OOM — **unverified, medium-high confidence**

`lib/models/dosage.dart:47` + `lib/domain/analytics_service.dart:375` +
`lib/screens/stats/stats_bundle.dart:124-127`

Two feeds into one quadratic:

* `Dosage.fromJson` falls back to `DateTime.fromMillisecondsSinceEpoch(0)` —
  1 Jan 1970 — for a timestamp it cannot parse. The stored-data path
  (`KratomProvider._decodeList`) applies no validation on top, unlike
  `backup_codec._parseDosages`, which rejects such a record.
* `StatsBundle.compute` deliberately runs the "All" range out to the latest
  dose when that is in the future.
* `theilSen` is O(n²) over **one point per calendar day in range**, and is
  called three times per `computeDrift`.

Failure scenario A (typo): the user fat-fingers a dose date as 2035 instead of
2025. The "All" range becomes ~3,900 days. Each fit builds a `List<double>` of
~7.6M pairwise slopes (~60MB) and sorts it, three times over. On a phone that
is an OOM or a multi-second freeze, not a slow frame.

Failure scenario B (corruption): one stored dosage record with an unparseable
`timestamp` becomes 1970-01-01. The range becomes ~20,600 days; ~212M slopes per
fit. The stats tab never renders again, and nothing tells the user why.

Today's history (~550 days → 151k slopes per fit) is comfortably fine, so this
is latent, not current.

**Not Tier 1** — the fix needs a decision the owner should make (reject the
record? clamp the range? subsample the fit?). Written up as Tier 2 proposal T2-1.

### 6. A failed write leaves the UI silently out of sync with disk — **unverified, medium confidence**

`lib/providers/kratom_provider.dart:200-203` (and every sibling mutator)

```dart
_dosages.add(dosage);
_invalidateComputedData();
await _save({_dosagesKey: _encodeDosages()});   // throws -> we never reach
_notifyMutation();                              // the notify
```

If `_save` throws, the dose is in memory and absent from disk, and no listener
is notified. The user sees a stale screen; on next launch the dose is gone. The
in-memory list is not rolled back either, so the *next* successful write will
persist it — the outcome depends on whether another dose is logged before the
app is killed.

**Not Tier 1** — correct behaviour here (roll back? surface an error? retry?) is
a design decision. Tier 2 proposal T2-2.

### 7. `_decodeList` turns a load failure into permanent data loss — **unverified, medium confidence**

`lib/providers/kratom_provider.dart:398-401`

Any exception decoding the stored dosage list returns `[]` and logs to
`debugPrint`. The app then boots looking empty. The *next* mutation calls
`_save({_dosagesKey: _encodeDosages()})`, which overwrites the stored JSON with
the near-empty in-memory list — the only copy of 18 months, gone, with no
prompt and no backup taken.

This requires the stored JSON to be genuinely corrupt (a deterministic
`jsonDecode` will not fail transiently), so the trigger is rare. The
*consequence* is total, which is why it is here.

**Not Tier 1** — what to do instead (refuse to boot? boot read-only? snapshot
the unreadable blob aside?) is a design decision. Tier 2 proposal T2-3.

### 8. `_save` is not atomic across keys — **unverified, low-medium confidence**

`lib/providers/kratom_provider.dart:404-417`

The temp-key protocol is sound *per key*: `_readStored` prefers the temp key, so
once the temp write lands the new value is live, and the sequence self-heals on
the next save. But `deleteStrain` and `commitImport` write **two** keys, and a
kill between them leaves new strains beside old dosages (or vice versa). That is
inconsistency, not loss — orphaned dosages survive rather than disappear — so it
is ranked low.

**Not Tier 1.** Tier 2 proposal T2-4.

### 9. Stats bundle memoisation does not invalidate at midnight — **unverified, medium confidence**

`lib/screens/stats_screen.dart:143`

`_resolveBundle` keys on `(range, provider.lastMutationStamp)`. I checked the
stamp: **every mutator does increment it**, so the task's specific worry is
unfounded. But `StatsBundle.compute` also closes over `DateTime.now()`, which is
not in the key. An app left open across midnight keeps serving a bundle whose
"today", 30-day window and unfinished-today rule all belong to yesterday, until
the next mutation. Low user impact (one stale screen until the first dose of the
day) but it is a real staleness hole.

**Not Tier 1** (needs a decision on how to observe the rollover). Tier 2
proposal T2-5.

---

## Checked and found healthy

Recorded so the owner does not pay to re-audit these.

**Domain arithmetic — re-derived independently, no defects found:**

* `theilSen` (`analytics_service.dart:375`) — median of pairwise slopes,
  intercept as median residual; `dx == 0` guarded; `< 2` points guarded.
* `_fitChangePercent` (`:530`) — reduces to `slope × span / intercept`; the
  `intercept <= 0.05` guard correctly refuses divide-by-noise.
* `trailingMedian` / `trailingWindow` (`:150`) — trailing not centred, entries
  sorted before windowing, partial left-hand windows handled.
* `IntakeFactors.of` (`:340`) — `gramsPerDay == dosesPerDay × gramsPerDose`
  holds exactly by construction; `doses == 0` guarded.
* `computeDoseSpacing` (`:922`) — median-of-daily-medians, same-day pairs only;
  the reasoning in its doc comment about the naive version converging on
  `24h / dosesPerDay` is correct.
* `computeReturnCycle` (`insights_service.dart:171`) — episode collapsing is
  correct; `lastEnd` is updated per episode, not per dose; recent/previous
  windows are symmetric 90-day spans.
* `computeRotationBreadth` (`:276`) — `1 / Σ(share²)` correct; an even n-way
  split returns exactly n.
* `computeFirstDoseDrift` (`:348`) — the circular median is **correct**. I tried
  to construct a wrap-around failure for `deltaMinutes` (which is not itself
  wrapped to ±720) and could not: because the anchor is the circular mean of
  *both* windows, two unimodal clusters always unwrap to within 720 minutes of
  each other. It only degrades when a window is near-uniform around the clock,
  where the median is meaningless anyway. **Not a defect.**
* `computeDrift` driver attribution (`:507`) — the 0.45 "both" band and the
  rest-day exclusion from `sizeFit` are right; a zero on a rest day really would
  read as shrinking doses.
* Unfinished-today rule — implemented consistently in `computeDoseStats:51` and
  `closedDayFacts:295`, and the two conditions are equivalent.
* `grandTotals` (`:776`) — future-dated doses clamped so the span cannot read
  negative; `daysTracked` vs `activeDays` distinction is correct and worth
  keeping.

**Timestamp localisation:** every read site in `lib/domain/` localises before
touching a date, hour or weekday. `hourHistogram`, `rotationSummary`,
`dailyTotals`, `computeDayRhythm`, `_completedDays` all check. `daysBetween`
computing in UTC to be DST-exact is correct.

**Provider:** the mutation stamp does increment on every mutation (checked all
nine mutators). `_mergeById` is order-stable and existing-wins as documented.
`_validatePayload` rejects duplicate and empty IDs, non-finite and out-of-range
amounts. `clearAllData` removes the user name — the regression its comment
describes is genuinely fixed. `_enqueueWrite` serialises correctly and does not
lose updates: each mutator encodes the whole list synchronously before
enqueueing, so a later write always supersedes an earlier one with the same
content plus its own.

**Android:** manifest is clean — no permissions in release, `allowBackup=false`,
one exported activity (the launcher, correctly exported), `minSdk` floored at 23.
The `gradle.taskGraph.whenReady` guard that fails a release build with no
keystore rather than shipping debug-signed is a good call. `key.properties` is
gitignored; only the `__REPLACE__` example is tracked.

**Baseline reproduced:** `flutter analyze` → exactly 4 `deprecated_member_use`,
matching the brief. `flutter test` → 207 passing before my change, 210 after.

---

## Tier 2 / Tier 3 proposals — write-up only, not implemented

**T2-1 — Bound the trend fit (finding 5).** *What:* cap the number of points fed
to `theilSen`, or cap the "All" range span, or validate timestamps on load.
*Why:* one bad date turns a 150k-operation fit into a 200M-operation one.
*Risk:* subsampling changes a published statistic; the owner said to argue
thresholds with statistics, and I have not done that work. *Cost:* small code,
real thought.

**T2-2 — Decide what a failed write means (finding 6).** *What:* roll back the
in-memory mutation on write failure, or surface it. *Risk:* rolling back after a
partial platform write could itself lose data. *Cost:* small.

**T2-3 — Stop treating an unreadable store as an empty one (finding 7).**
*What:* on decode failure, refuse to overwrite; copy the unreadable blob to a
side key and tell the user. *Why:* this is the only path found that can destroy
all 18 months silently. *Risk:* a boot-blocking error state is its own hazard.
*Cost:* small code, needs a UI decision.

**T2-4 — Make multi-key saves atomic (finding 8).** *What:* one versioned blob,
or a commit marker. *Risk:* changes the on-disk format; migration needed.
*Cost:* moderate. *YAGNI note:* the observed consequence is orphaned dosages,
not lost ones — this may not be worth the format change.

**T2-5 — Invalidate the stats bundle at midnight (finding 9).** *What:* include
the current calendar day in `_resolveBundle`'s key. *Cost:* trivial, but needs a
decision on what triggers the re-read.

**T3-1 — `WeekdayRhythm` on an all-zero window.** `analytics_service.dart:877`:
if every weekday mean is 0, `means[busiest] - means[quietest] < means[busiest] *
0.08` is `0 < 0`, which is false, so the flat-week guard does not fire and
Monday is named both busiest and quietest. Reaching it needs ≥12 occurrences of
every weekday with zero grams throughout — 84+ logged days with no doses at all.
Not worth a change on its own; noted in case the guard is touched for another
reason.

---

## Handoff — what is left

Branch: `audit/v2.16.0`, based on `main` @ `a72f5a2`. One commit so far
(`7c5ea09`). Nothing has been pushed. `main` untouched, no force-pushes.

### Tier 1 still to implement

1. **Findings 2, 3, 4 — localise before display.** Six call sites, listed above.
   Write the failing test first; `test/export/csv_export_test.dart` is the
   cheapest place to start (pure function, a UTC-timestamped fixture fails
   before and passes after). `report_screen`'s `_groupDosagesByDate` is private,
   so it needs a widget test or a small extraction.
2. **The 4 known deprecations.** APIs confirmed against Flutter 3.44.9:
   `TickerMode.of(context)` → `TickerMode.valuesOf(context).enabled`
   (`home_dosage_list.dart:528`, `:722`); `Radio.groupValue`/`onChanged` →
   wrap the `for (var type in _strainTypes.entries)` spread at
   `add_strain_form.dart:301-325` in a single `RadioGroup<String>(groupValue:,
   onChanged:, child: Column(...))` and drop both params from the `Radio`.
   After this, `flutter analyze` must report **0**.
3. **Unused deps and dead assets.** `lottie` has zero references and can go
   outright. **`flutter_svg` is *not* unused** — `tools/generate_icon.dart`
   imports it. That tool writes `assets/icon/icon.png` and
   `icon_foreground.png`, which do not exist and which nothing consumes
   (`flutter_icons` in pubspec builds from `assets/icon/app_icon.png`), so it is
   a dead one-off. Removing the dep means removing the tool; that is a judgement
   call the owner should see. `assets/animations/` (4 files, ~100KB) is
   unreferenced — delete the directory and the whole `assets:` block in pubspec.
   Keep `assets/icon/kratom.svg` (925B, source art).
4. **`MaterialApp.title`** at `lib/main.dart:47` and `:82` — `'Kratom Tracker'`
   → `'Herbal Tracker+'`.
5. **Jetifier / CI OOM.** See the blocker below before touching this.

### Not started

* Item 4 of the brief — the stats and home screens judged **as products**
  (does each section earn its space, are the insight sentences readable). I read
  `stats_insights.dart` and the sentences do read as plain English; I did not
  get to a considered view on the section ordering or on whether anything is
  silent when it has plenty to say.
* Item 5 — **test quality**. One gap already visible: the fixtures in
  `test/domain/insights_test.dart` build days with `Duration(days:)`
  (`_day`, line 15), the exact elapsed-hours pattern `date_utils` exists to
  prevent — those tests would break in a DST zone. And **no test anywhere
  covers a UTC-carrying import**: `test/data/legacy_migration_test.dart` uses
  naive local timestamps throughout, so the single most defect-prone path in
  the codebase is unguarded. That absence is what let findings 2–4 survive.
* `lib/widgets/`, `lib/screens/manage_screen.dart`, `strains_screen.dart`,
  `theme_provider.dart`, `web_backup_service.dart` — not read.
* `android/app/proguard-rules.pro` and the tail of `.github/workflows/main.yml`
  — not read.

### Environment blocker — read this first

**`flutter build apk --release` cannot run in this container.** The Flutter SDK
was installed by hand at `/opt/fl/flutter` (3.44.9 stable, matches the brief);
`analyze` and `test` work. But there is no Android SDK, and
**`dl.google.com` is blocked by the network policy** (`403` on CONNECT), which
is where `cmdline-tools` and every platform/build-tools package live.
`maven.google.com`, `services.gradle.org` and `repo1.maven.org` *are* reachable,
so this is specifically the SDK download that fails. A release build also needs
a keystore, which by design lives outside the repo — a throwaway keystore
pointed at by `KRATOM_KEYSTORE_PROPERTIES` would satisfy that part, but the SDK
is the hard blocker.

**Consequence for the Jetifier fix:** the brief's own verification gate —
"confirm no `com.android.support` artifact appears anywhere in
`./gradlew :app:dependencies` before disabling Jetifier, then prove the release
build still works" — **cannot be satisfied here**. Do not disable Jetifier
blind; it is the one change in the Tier 1 list that can break the owner's only
release path, and it is unverifiable in this environment. Either run it where
the SDK is reachable, or move it to Tier 2 with that reason stated. A partial
static check (grepping the resolved plugins' Gradle files in the pub cache for
`com.android.support`) is available as supporting evidence but is not the gate
the brief asked for.

**Reproducing the environment:**

```
curl -sSL -o f.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.9-stable.tar.xz
tar xf f.tar.xz -C /opt/fl && export PATH=/opt/fl/flutter/bin:$PATH
git config --global --add safe.directory /opt/fl/flutter
flutter pub get
```

### VERIFY status

| command | result |
| --- | --- |
| `flutter analyze` | **4 issues**, all `deprecated_member_use` — unchanged from baseline, as expected until the deprecations are fixed. Must become **0** once they are. |
| `flutter test` | **210 passing** (baseline 207, +3 from `test/screens/home_calendar_week_test.dart`). |
| `flutter build apk --release` | **not run** — blocked, see above. |
