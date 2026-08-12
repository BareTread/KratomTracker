# Herbal Tracker+

A private, offline Flutter app for tracking daily herbal supplement doses. Dark mode only,
Android first. All data stays on the device — no account, no network, no analytics.

- **Package**: `org.kratomtracker.plus`
- **Version**: 2.12.0+14 (`pubspec.yaml`, mirrored in `lib/constants/app_version.dart` and
  enforced by `test/app_version_test.dart`)
- **Flutter**: 3.44.x stable, Dart SDK `^3.5.4`
- **Min Android**: API 23 (6.0)

## What it does

- **Doses** — log a dose in two taps (strain, then amount). Timestamps are editable.
- **The day view** — the home screen is a horizontal pager of days. Each day draws a
  botanical "vine": a painted stem with one leaf mark per dose, and a live dashed tail
  running from the last dose down to a NOW node so elapsed time is readable at a glance.
- **Strains** — around thirty, each with its own colour and leaf shape. Stock tracking.
- **Effects** — optional per-dose ratings (energy, mood, pain relief, focus, anxiety).
- **Stats & reports** — usage trends, per-strain breakdowns, CSV/JSON export and import.

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
flutter test                        # 23 test files
flutter analyze
flutter run                         # debug — NOT representative of animation smoothness
flutter build apk --release
```

### Release signing

Release builds need `android/key.properties`, which is gitignored and must never be
committed. Copy `android/key.properties.example` and fill it in; the keystore itself lives
outside the repo. Without it, `flutter build apk --release` fails with an explicit message
rather than silently producing an unsigned or debug-signed APK.

Verify what you actually built, independently of the build's exit code:

```bash
/opt/android-sdk/build-tools/37.0.0/aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | head -1
# package: name='org.kratomtracker.plus' versionCode='14' versionName='2.12.0'
```

## Performance notes

The home screen paints continuously (the live dashed tail animates on a 2.8s loop), so it is
the first place to look if frames drop. As of 2.12.0 the animation architecture was audited
and is sound — record this so it is not re-litigated:

- Both live tails are already isolated in their own `RepaintBoundary` + ticker
  (`home_dosage_list.dart:588`, `:791`), so the animated tail does **not** repaint the static
  vine or the leaf marks.
- Offscreen tickers already stop — `TickerMode.of(context)` guards both controllers
  (`home_dosage_list.dart:543`, `:737`).
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
painters build gradients and path metrics inside `paint()` (`vine_painter.dart:279`, `:293`,
`:320`). Memoizing those is the next performance change if one is ever needed.

**Always profile in `--profile` mode.** Debug builds are not indicative of release
smoothness, and a fresh install can be janky for unrelated reasons (background dexopt, Play
Protect scanning, the display dropping to 60Hz on low battery).

## Housekeeping

`lottie` and `flutter_svg` are declared in `pubspec.yaml` but no longer imported anywhere in
`lib/`. They can be dropped whenever someone is touching dependencies.

`MaterialApp.title` still reads "Kratom Tracker" (`lib/main.dart:47`, `:82`) while the Android
launcher label is "Herbal Tracker+".

## Privacy

Everything is stored locally in `SharedPreferences`. There is no backend, no telemetry, and
no account. Export writes a file you choose to share; nothing leaves the device otherwise.

## Licence

MIT — see [LICENSE](LICENSE).
