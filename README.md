# Herbal Tracker+

A private, offline Flutter app for tracking daily herbal supplement doses. Android first,
with light and dark themes. All data stays on the device — no account, no network, no
analytics.

- **Package**: `org.kratomtracker.plus`
- **Current release**: 2.18.1+29 (`pubspec.yaml`, mirrored in
  `lib/constants/app_version.dart` and enforced by `test/app_version_test.dart`)
- **Flutter**: 3.44.x stable, Dart SDK `^3.5.4`
- **Min Android**: API 23 (6.0)
- **Previous release**: [v2.16.3](https://github.com/BareTread/KratomTracker/releases/tag/v2.16.3)

## What it does

- **Doses** — log from one sheet with a preselected suggestion, or repeat the last dose.
  Timestamps are editable; one-tap logs and deletes offer Undo.
- **The day view** — the home screen is a horizontal pager of days. Each day draws a
  botanical "vine": a painted stem with one leaf mark per dose, and a live dashed tail
  running from the last dose down to a NOW node so elapsed time is readable at a glance.
- **Strains** — around thirty, each with its own colour and leaf shape. Stock tracking.
- **Stats & reports** — range-aware totals, trajectory and rotation insights, a 30-day
  herbarium, per-strain breakdowns, and CSV/JSON export and import.

## 2.18.1

- Undo confirmations (log, log again, delete) dismiss themselves after 4 seconds; a new
  one replaces the last instead of queueing. Delete from the dose sheet always offers Undo.
- Restore rejects a backup whose every record is unreadable instead of wiping the log. A
  corrupt stored daily limit (NaN) no longer breaks saving and backup.
- A notes-only dose edit keeps the stored amount (2.347g no longer becomes 2.35g).
- Calendar taps select the right day west of UTC; a strain's "Log a dose" logs today;
  double-tapping "Add strain" creates one strain.
- Backup and CSV share messages no longer claim a file was saved. The load warning is a
  banner with Dismiss and Open.
- Stats: the All-range drift headline names its 6-month window; median labels and
  Report amounts use the same rounding as Home. Strain details show local dates.
- Layout holds at system font sizes up to 2x. MaterialApp no longer rebuilds on every
  dose and day swipe.

## 2.18.0

- One-sheet dose logging preselects the top in-stock suggestion and its last amount;
  repeat the last dose from the FAB menu. One-tap logs and deletes offer Undo.
- Day-sprig glyphs show doses in the Stats 30-day herbarium and Home week strip.
- Strains, Stats, Manage, Report and sheets are redesigned. Appearance follows System,
  Light or Dark; the bottom navigation uses an active dot instead of the Material pill.
- Restore keeps doses with missing strains under out-of-stock placeholders. Replace import
  requires explicit strain and dosage lists. Damaged rows no longer hide other history;
  Manage shows load warnings.
- Removed unused reminder, notification and tolerance settings. Storage remains the
  per-key journal; batching commits is deferred.

## Layout

```
lib/
├── constants/      app_version.dart (kept in sync with pubspec)
├── domain/         analytics, date maths, strain usage rollups
├── models/         Dosage, Strain, Effect, Settings (+ _coerce.dart for tolerant parsing)
├── providers/      KratomProvider (all state), ThemeProvider (builds both themes)
├── theme/          app_theme.dart: AppColors (light + dark), AppType, AppMotion
├── screens/
│   ├── home/       day card, dosage list, calendar strip, FAB menu, empty state
│   └── *.dart      manage, strains, stats, report, privacy, terms
└── widgets/        forms and sheets, plus the two painters below
```

Two files carry the visual identity and deserve care:

- `lib/widgets/vine_painter.dart` — `VineGeometry` (where the stem sits relative to the
  marks), `VineRhythm` (adaptive vertical spacing, computed per layout from the viewport
  height and the dose count), and the three stem painters.
- `lib/widgets/strain_mark.dart` — `LeafMarkPainter`, which draws every strain's leaf
  shape at one shared optical weight.

### Design law

Rules the UI does not break:

1. **Cyan means now or act.** Nothing decorative is cyan.
2. **Strain colour means identity.** Use it on the strain mark and code only.
3. **Everything else is warm ink/paper neutrals** (`AppColors`, dark and light). Take colours
   from `context.c`; do not hard-code.
4. **Two typefaces, bundled in `assets/fonts`:** Hanken Grotesk (`AppType.sans`) for UI,
   Instrument Serif (`AppType.display`) for figures and screen titles only. Tracked-caps
   labels are reserved for Stats section heads; labels elsewhere are sentence-case grey.
   `CustomPainter` text does not inherit the theme font; set `fontFamily` explicitly.
5. **Show the exception, not the default.**

### Home screen hierarchy

Decided with the user; do not drift back:

- **The strain code is the headline of a dose row** (26px, bold, in the strain's colour).
  Amount and full name are small supporting text under it. Amounts barely change between
  doses; the strain is what the eye reads the day by. Never lead with the full name or amount.
- **Nothing is pinned to a row's right edge.** The FAB sits over the last row of a full day
  and covered right-aligned amounts.
- **Headline figure is state-dependent and modest (30px):** today = time since last dose
  (the most important number), past day = that day's total.
- **Strain colour is clamped for legibility** (`legibleStrainColor`). Small text in the
  light theme is additionally darkened (`codeColor` in `home_dosage_list.dart`); yellow and
  white strains sit near 2:1 on cream otherwise.
- **Motion:** each day page plays one staggered reveal (`_Entrance`, one controller per
  page), not on every dose edit. After a log, the new row's strain mark settles once;
  motion honours `AppMotion.reduced`.
- Gram-leaves on dose rows were tried behind the text and then under it; both were
  rejected as clutter. Do not re-add them.
- Under a minute since the last dose the header reads `0m` and the live gap is silent;
  gap labels start at 1m. The word "now" appears only at the NOW tip.
- The week strip shows micro-sprigs instead of presence dots. Tap the FAB for the log
  sheet; long-press for Add Strain, Add Dose and repeat last dose. Back closes the menu.
  The suggested in-stock strain and its last amount are preselected, and Save names both;
  one-tap logs and deletes offer Undo for 5 seconds.

In the Stats 30-day herbarium, each stem runs midnight to midnight. Each leaf is a dose
at its time, with length in grams on a shared scale and colour by strain; a bud marks a
rest day. The heaviest day shows its total. The week strip uses the same encoding with a
scale shared across that week.

## Build

```bash
flutter pub get
flutter test
flutter analyze
flutter run                         # debug — NOT representative of animation smoothness
flutter build apk --release --split-per-abi   # the only APK form that installs; see below
flutter build appbundle --release
# Screenshots without a device (the Linux desktop build is not possible here):
flutter test test/tools/design_shots_test.dart --dart-define=SHOTS_DIR=/abs/dir
flutter test test/tools/home_shots_test.dart --dart-define=SHOTS_DIR=/abs/dir
flutter test test/tools/sprig_shots_test.dart --dart-define=SHOTS_DIR=/abs/dir
#   -> <dir>/<dark|light>_<home|home_past|home2|strains|stats|manage|adddose>.png
```

Concurrent Flutter runs on this machine should use `flock /tmp/kt-flutter.lock flutter ...`
to serialize access.

Screenshots show layout and colour only; animation feel needs a device. Any visible change
needs a version bump in both `pubspec.yaml` and `lib/constants/app_version.dart`.

### Release signing

Release builds need `android/key.properties`, which is gitignored and must never be
committed. Copy `android/key.properties.example` and fill it in; the keystore itself lives
outside the repo. Without it, `flutter build apk --release` fails with an explicit message
rather than silently producing an unsigned or debug-signed APK.

The only update-capable signing key is
`~/.android-keystores/kratomtracker-plus.jks`; keep its off-machine backup. The local
`android/key.properties` points to it. Losing the key means future builds cannot upgrade
the installed Plus app.

**Install gotcha:** a phone running a split build rejects the universal `app-release.apk`
as "app not installed as it appears to be invalid" (versionCode downgrade, see the ABI
offsets in the polish notes below). Always install `app-arm64-v8a-release.apk`, and bump the
`+N` build number for every build you hand over.

Verify what you actually built, independently of the build's exit code. The APK must report
package `org.kratomtracker.plus`, the intended version/code (arm64 = 2000 + `N`), and
signing certificate SHA-256
`d6febe8e8dea5ae5d483c2145095e2ea04958353e68743be195deab55439180c`:

```bash
apk=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
bt=~/dev-sdks/android/build-tools/35.0.0
$bt/apksigner verify --print-certs $apk | grep SHA-256
$bt/aapt2 dump badging $apk | head -1     # package, versionCode, versionName
jarsigner -verify build/app/outputs/bundle/release/app-release.aab
```

GitHub currently has no signing secrets. Actions therefore builds and labels a
`*-unsigned-debugkey.apk` verification artifact; it is **not** a distributable release and
the workflow cannot attach it to a GitHub Release. Build signed APK/AAB files locally,
verify them as above, tag the exact `main` commit, and upload both manually:

```bash
git tag -a vX.Y.Z -m "Herbal Tracker+ vX.Y.Z"
git push origin vX.Y.Z
gh release create vX.Y.Z HerbalTrackerPlus-X.Y.Z.apk HerbalTrackerPlus-X.Y.Z.aab \
  --title "Herbal Tracker+ vX.Y.Z" --verify-tag --notes-file RELEASE_NOTES_FILE
```

Do not publish until `flutter analyze`, the full test suite, the signed local builds, and
both the `main` and tag Actions runs pass. Test the APK by installing it over the previous
Plus release without uninstalling, confirming that its data remains intact.

## Legacy 1.0 migration

The original app and Plus are deliberately separate Android apps:

- Original 1.0: `org.kratomtracker.app`, preserved on branch `legacy-1.0`
- Herbal Tracker+ 2.x: `org.kratomtracker.plus`, released from `main`

Installing Plus does not replace or delete 1.0. Export from 1.0, import into Plus, verify
the dose count and date range, then manually uninstall 1.0. Never change either application
ID to make them overwrite each other.

## Audit state at v2.16.1

The August 2026 audit re-derived the analytics calculations and found no arithmetic defect.
It fixed calendar/DST indexing, local display of imported UTC timestamps, the Android CI
Jetifier heap failure, Flutter API deprecations, and remaining public-facing old names.

Recovery-hardening items still open:

1. Reject or bound malformed/far-future timestamps before all-range Theil–Sen work.
2. Review batching storage commits separately; the shipped per-key journal remains in use.
3. Replace the iOS bundle ID placeholder before an iOS release.

Damaged rows are isolated and raw damaged strings are copied to additive quarantine keys
before overwrite; quarantine is evidence for manual recovery, not an automatic restore
source. Load and import warnings reflect current evidence, not old quarantine entries.
Replace import requires both explicit lists (empty lists are allowed); historical bare dose
lists can be merged. Backup format remains version 1. Old reminder and tolerance fields
are accepted and ignored.

## Polish pass — 2026-08-15 (post-v2.16.2)

A second-opinion review of the phone diagnostic plus the full codebase produced five
changes; everything else on the idea list was deliberately left alone (reasoning and
corrections to the review itself are appended in `improvement-ideas-2026-08-15.md`).

1. **Undo on dose delete** (`home_dose_actions.dart`). The confirm dialog is gone;
   deleting is one tap and the "Dose deleted" snackbar carries an Undo action that
   re-adds the dose at its original timestamp (fresh ID — nothing keys on dose IDs;
   guarded for the strain-also-deleted case). A wrong-row delete now costs one tap
   back instead of a modal on every delete.
2. **Strain-edit sheet blur removed** (`strains_screen.dart`). The sheet ran a
   full-surface `BackdropFilter` at sigma 5 behind an ~85%-opaque container for the
   whole edit session — GPU cost, no design value. Now an opaque surface matching
   the strain-options sheet in the same file. Also deleted
   `lib/services/mobile_backup_service.dart` and `web_backup_service.dart`
   (`BackupFileService`, imported nowhere; Manage backs up inline).
3. **Live-tail dash caching** (`vine_painter.dart`, `home_dosage_list.dart`). The
   dash pattern repeats every 2+7=9px and the tail drifts 36px/2.8s ≈ 0.2px per
   vsync at 120Hz, so the phase is quantized to whole pixels: at most 9 cached
   dashed paths per geometry (24 growth steps for the sprout, deterministic per
   loop) instead of `computeMetrics`/`extractPath` on every vsync of an infinitely
   repeating animation. Quantized offsets also flow into `shouldRepaint`, so frames
   between phase steps skip the raster entirely — ~13 repaints/s instead of ~120 on
   a dosed today. The sprout keeps full phase resolution for smooth growth.
4. **Dark cold start** (`android/.../res/values*/styles.xml`, `launch_background.xml`,
   `colors.xml`). Launch and normal windows were pinned to the dark scaffold colour
   `#090B0C`, with `windowSplashScreenBackground` set for Android 12+; appearance now
   also supports System and Light.
5. **Split-per-ABI release APK** (`.github/workflows/main.yml`). `--split-per-abi`;
   arm64 keeps the plain `kratom-tracker-vX-release.apk` name (phone install and
   GitHub Release attachment unchanged); armeabi-v7a and x86_64 ride along as
   renamed workflow artifacts. Roughly a quarter of the previous download size.
   Note: split builds offset each APK's versionCode (arm32 +1000, arm64 +2000,
   x64 +4000 over the pubspec base), so the arm64 2.16.2 build installs as
   **2021**. Keep distributing split APKs from here on; a future universal APK
   would need a base code above the highest installed split code or Android
   rejects it as a downgrade.

Not done at the time: the day-indexed dose map, incremental persistence, stats isolate,
`performanceMode` Manage toggle, and system-follow theme mode. System appearance was
added in 2.18.0.

### On-device check (2026-08-15, OnePlus 12, after the polish pass)

`top` delta windows over ADB, per-core convention (100% = one core), same
trickle-charging USB condition as the diagnostic report:

- Idle on Home **today**, live tail animating at 120Hz: **~24% of one core**
  (≈3% of total device capacity).
- Flinging through past days (page movement verified by screenshot): **~13% of
  one core** — past days have no live tail, so flinging costs less than the
  animated today page.
- Static past-day page: **0% CPU, 14 minor faults** — fully static, as designed.

No A/B against the old build was possible on the daily phone (the tagged fat APK
is a versionCode downgrade and uninstalling would wipe data), so the comparison
baseline is the diagnostic report's single old-build window: 28% of total capacity
(~2.2 cores) during interaction. The new build's worst sustained app-process figure
is ~0.24 core. The residual on today is the two tickers still scheduling a frame
per vsync to advance the quantized dash phase; paint and raster are skipped between
phase steps. If that residual ever matters, halving the tail's tick rate or pausing
it under covering sheets is the next lever — not needed now.

## Performance notes

The home screen paints continuously (the live dashed tail animates on a 2.8s loop), so it is
the first place to look if frames drop. The animation architecture was audited before 2.16.1
and is sound — record this so it is not re-litigated:

- Both live tails are already isolated in their own `RepaintBoundary` + ticker
  (`home_dosage_list.dart:570`, `:773`), so the animated tail does **not** repaint the static
  vine or the leaf marks.
- Offscreen tickers already stop — `TickerMode.valuesOf(context).enabled` guards both controllers
  (`home_dosage_list.dart:529`, `:723`).
- `ListView.builder` wraps each row in a `RepaintBoundary` itself (framework default,
  `addRepaintBoundaries: true`). Do not add another by hand; grepping this repo for
  `RepaintBoundary` will not show it.
- Vine painter `shouldRepaint` compares primitives, and `VineRhythm.compute` runs inside
  `LayoutBuilder` — per layout, not per frame.
- Day swipes are smooth because `home_screen.dart` drives the focused day through a
  `ValueNotifier` and defers the provider commit to `ScrollEndNotification`, with each page
  in its own `RepaintBoundary`.
- The herbarium uses one `CustomPainter` per day; its `shouldRepaint` compares sorted
  dose lists.

Known remaining cost, not yet addressed: `LeafMarkPainter` rebuilds its stroke `Path`s and
recomputes per-shape ink bounds on every paint (`strain_mark.dart:94`, `:115`), and the vine
painters build gradients inside `paint()` (`vine_painter.dart:279`, `:293`). The live tail's
per-frame path metrics were cached in the 2026-08-15 polish pass above; memoizing the rest
is the next performance change if one is ever needed.

**Always profile in `--profile` mode.** Debug builds are not indicative of release
smoothness, and a fresh install can be janky for unrelated reasons (background dexopt, Play
Protect scanning, the display dropping to 60Hz on low battery).

## Privacy

Everything is stored locally in `SharedPreferences`. There is no backend, no telemetry, and
no account. Export writes a file you choose to share; nothing leaves the device otherwise.

## Licence

MIT — see [LICENSE](LICENSE).
