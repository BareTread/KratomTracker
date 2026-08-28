# Herbal Tracker+

A private, offline Flutter app for tracking daily herbal supplement doses. Android first,
with light and dark themes. All data stays on the device — no account, no network, no
analytics.

- **Package**: `org.kratomtracker.plus`
- **Current release**: 2.16.3+22 (`pubspec.yaml`, mirrored in
  `lib/constants/app_version.dart` and enforced by `test/app_version_test.dart`)
- **Flutter**: 3.44.x stable, Dart SDK `^3.5.4`
- **Min Android**: API 23 (6.0)
- **Release**: [v2.16.3](https://github.com/BareTread/KratomTracker/releases/tag/v2.16.3)

## What it does

- **Doses** — log a dose in two taps (strain, then amount). Timestamps are editable.
- **The day view** — the home screen is a horizontal pager of days. Each day draws a
  botanical "vine": a painted stem with one leaf mark per dose, and a live dashed tail
  running from the last dose down to a NOW node so elapsed time is readable at a glance.
- **Strains** — around thirty, each with its own colour and leaf shape. Stock tracking.
- **Stats & reports** — range-aware totals, trajectory and rotation insights, per-strain
  breakdowns, and CSV/JSON export and import.

## Layout

```
lib/
├── constants/      app_version.dart (kept in sync with pubspec)
├── domain/         analytics, date maths, strain usage rollups
├── models/         Dosage, Strain, Effect, Settings (+ _coerce.dart for tolerant parsing)
├── providers/      KratomProvider (all state), ThemeProvider (the dark theme)
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

Four rules the UI does not break:

1. **Cyan means interactive.** Nothing decorative is cyan.
2. **Strain colour means identity.** It marks which strain a dose was, nothing else.
3. **Everything else is greyscale** on a near-black ground.
4. **Hairlines are 1.5px.**

## Build

```bash
flutter pub get
flutter test
flutter analyze
flutter run                         # debug — NOT representative of animation smoothness
flutter build apk --release
flutter build appbundle --release
```

### Release signing

Release builds need `android/key.properties`, which is gitignored and must never be
committed. Copy `android/key.properties.example` and fill it in; the keystore itself lives
outside the repo. Without it, `flutter build apk --release` fails with an explicit message
rather than silently producing an unsigned or debug-signed APK.

The only update-capable signing key is
`~/.android-keystores/kratomtracker-plus.jks`; keep its off-machine backup. The local
`android/key.properties` points to it. Losing the key means future builds cannot upgrade
the installed Plus app.

Verify what you actually built, independently of the build's exit code. The APK must report
package `org.kratomtracker.plus`, the intended version/code, and signing certificate SHA-256
`d6febe8e8dea5ae5d483c2145095e2ea04958353e68743be195deab55439180c`:

```bash
tracker_android_sdk=$(sed -n 's/^sdk.dir=//p' android/local.properties)
$tracker_android_sdk/cmdline-tools/latest/bin/apkanalyzer manifest application-id build/app/outputs/flutter-apk/app-release.apk
$tracker_android_sdk/cmdline-tools/latest/bin/apkanalyzer manifest version-name build/app/outputs/flutter-apk/app-release.apk
$tracker_android_sdk/cmdline-tools/latest/bin/apkanalyzer manifest version-code build/app/outputs/flutter-apk/app-release.apk
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
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

Three recovery-hardening items remain intentionally deferred; address them in a focused
change with failure-path tests and an explicit data-recovery policy:

1. Reject or bound malformed/far-future timestamps before all-range Theil–Sen work.
2. Define rollback and UI error behavior when persistence fails after an in-memory mutation.
3. Preserve corrupt raw stored JSON instead of allowing a later write to replace it with an
   empty decoded list.

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
   `colors.xml`). Launch and normal windows are pinned to the scaffold colour
   `#090B0C`, and `windowSplashScreenBackground` is set for the Android 12+ system
   splash. The app defaults to its dark theme regardless of system theme, so the
   launch window now follows the app instead of flashing white/cyan into it.
5. **Split-per-ABI release APK** (`.github/workflows/main.yml`). `--split-per-abi`;
   arm64 keeps the plain `kratom-tracker-vX-release.apk` name (phone install and
   GitHub Release attachment unchanged); armeabi-v7a and x86_64 ride along as
   renamed workflow artifacts. Roughly a quarter of the previous download size.
   Note: split builds offset each APK's versionCode (arm32 +1000, arm64 +2000,
   x64 +4000 over the pubspec base), so the arm64 2.16.2 build installs as
   **2021**. Keep distributing split APKs from here on; a future universal APK
   would need a base code above the highest installed split code or Android
   rejects it as a downgrade.

Not done, deliberately: the day-indexed dose map, incremental persistence, and stats
isolate (no felt symptom at current scale — the "next performance change if one is
ever needed" bar below); the `performanceMode` Manage toggle (the dash cache removes
the cost it would have toggled); a system-follow theme mode (single user, dark-only
in practice).

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
- Every `shouldRepaint` compares primitives only, and `VineRhythm.compute` runs inside
  `LayoutBuilder` — per layout, not per frame.
- Day swipes are smooth because `home_screen.dart` drives the focused day through a
  `ValueNotifier` and defers the provider commit to `ScrollEndNotification`, with each page
  in its own `RepaintBoundary`.

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
