# Herbal Tracker+ — Improvement ideas

- **Date:** 2026-08-15
- **Scope:** evaluate only. No code changes.
- **Live GitHub branch:** `main` @ `e756ec9` (`origin/main`)
- **Live release:** v2.16.2+21 (`pubspec.yaml`, tag `v2.16.2`)
- **Repo:** https://github.com/BareTread/KratomTracker
- **Phone diagnostic (hints, not facts):** `/home/alin/DATA/Work/KratomTracker/kratomtracker-dev-report-2026-08-15.md`
  - Device: OnePlus 12, OxygenOS 16, 120 Hz, Snapdragon 8 Gen 3
  - Installed build: **2.16.1+20** (one release behind live `main`)
  - Method: ADB `dumpsys` only; agent did not know this codebase

---

## What was evaluated

GitHub `main` as it exists today: Flutter 3.44 / Dart ^3.5.4, package `org.kratomtracker.plus`, offline SharedPreferences store, no backend, no WorkManager, no AlarmManager, no `INTERNET` in the release manifest.

Home is the product surface: a horizontal day pager whose today-page paints a botanical vine with a live dashed tail. Strains / Stats / Manage are secondary tabs.

---

## What the phone report actually maps to

**Keep.** Absolute drain is tiny (0.916 mAh, 0.06% of device drain). Release build, targetSdk 36, no AlarmManager, no leaked services, cached-state CPU ≈ 0. That part is real.

**Foreground bursts (~2.2 cores, kernel-heavy, ~150 minor faults/s).** This is the home vine, not a mystery worker. Today always runs a 2.8 s looping ticker (`VineGeometry.livePeriod`). Every frame `dashPath()` does `Path.computeMetrics()` + `extractPath()` (`lib/widgets/vine_painter.dart`). On 120 Hz that is ~43 metric rebuilds/s for a dashed cubic. Isolation is already correct (`RepaintBoundary` + `TickerMode` + lifecycle stop on the 1-minute clock). Isolation does not make the Skia/Impeller work cheap.

**Background 2.4× foreground is not an app job.** `pubspec.yaml` has no WorkManager. The release manifest has no services, receivers, or `INTERNET`. The only timers are UI-scoped and cancelled in `paused` / `hidden` / `detached`. The 6 JobScheduler hits are almost certainly Flutter engine / Impeller / SharedPreferences / Play, not app work. Plugged-in + screen-off + concurrent AI agent + USB trickle-charge is a dirty attribution window. Do not hunt for a periodic backup loop that does not exist.

**Already fixed on live `main` vs the phone build.** One shared 1-minute `_now` ticker, resume jump, stop in background (`lib/screens/home_screen.dart`). Report checklist item 5 (“one shared 1 Hz ticker”) is done — and it is 1/minute, which is the right rate.

---

## Performance — ranked

### 1. Stop rebuilding dash metrics every frame

Highest-leverage match for the 2.2-core spike.

`dashPath` rebuilds path metrics on every vsync of the live tail. Cache `PathMetric` (or a pre-dashed atlas) per stem size; animate with a shader / `dashOffset` or a phase into a cached on/off list. Same look, ~1 metric build per layout instead of per vsync.

Empty-today sprout is worse: `saveLayer` + `computeMetrics` + extract every frame (`VineNowStemPainter.paint`, 3.4 s loop). Idle empty home is a continuous GPU tax.

### 2. Kill or shrink the FAB fullscreen blur

Long-press FAB does `BackdropFilter` + `ImageFilter.blur(1.5)` over `Positioned.fill` (`lib/screens/home_screen.dart`). Full-screen blur on a 120 Hz 1440p panel is a known 1–2 core burst. Dim overlay, or blur a small rect around the menu.

### 3. Index doses by day

`getDosagesForDate` scans the whole list and sorts (`lib/providers/kratom_provider.dart`). Calendar week does that 7× via `totalForDate`. Each `_HomeDayPage` does it again, plus `Object.hashAll` of the day's doses. Strains screen rescans **all** dosages per card (`lib/screens/strains_screen.dart`). Fine at hundreds of doses; gets sticky at a multi-year log, especially on day swipe.

One `Map<DateTime, List<Dosage>>` rebuilt on mutation. Calendar, vine, status line, strain “last used” all read it.

### 4. Incremental persist, not full JSON rewrite

Every `addDosage` / `updateDosage` / `deleteDosage` `jsonEncode`s the entire dosage list, then writes temp key + real key + delete temp (`_save`). Three SharedPreferences commits, binder + fsync. Matches the report’s kernel share on interaction, not a background job.

Append-only log, or SQLite, or at least one write. The deferred recovery items in the README (corrupt JSON, failed persist after in-memory mutation) sit on this same path.

### 5. Memoize leaf paths and vine shaders

README already names this. `LeafMarkPainter` rebuilds strokes and `_inkOf` every paint. `paintVinePath` allocates three `ui.Gradient.linear` shaders per segment, and a dose row paints two segments + petiole. Static; cache by `(shape, color, size)` and by gradient endpoints.

### 6. Don’t keep painting when Home isn’t visible

`MainScreen` swaps `body: _screens[_selectedIndex]` — Home is disposed off-tab, good. While Home **is** showing, two tickers run even if the live tail is off-screen on a long day. Pause them when the live gap / `NOW` row is not in the viewport, and when the screen is covered by the add-dose sheet.

`performanceMode` already exists on `UserSettings` and gates `AppMotion.reduced`. There is no Manage toggle. Expose it: freeze tails, skip blur, skip sprout.

### 7. Stats: one pass, or compute off-frame

`StatsBundle.compute` walks history separately for drift, rhythm, rotation, spacing, four insights, grand totals. Memoised per `(range, mutationStamp)` — good. First open of Stats on a long import can still hitch the tab switch. `compute()` / isolate, or one sorted scan that fills every struct.

### 8. Ignore unless you feel it

- `PageView` of 10 001 pages: cheap builders, already `RepaintBoundary`’d.
- `table_calendar` for a 7-cell strip: overweight, not hot.
- Trajectory chart: paints once per range change.
- Impeller default is fine; don’t chase engine flags until (1) and (2) are done.

---

## Look and feel — ranked

Home is the product. Strains / Manage / nav still look like a different app. That split is the main visual problem.

### 1. Finish the design system on Strains and Manage

Home: near-black `#090B0C`, `AppColors`, hairline cards, cyan only for interactive, strain colour only for identity.

Strains: hardcoded `Colors.black` / `Colors.white` / `Colors.grey[500]`, `#1A1A1A` cards, no hairline, `addRepaintBoundaries: false`. Manage: Material `Card` + `ListTile`, section headers in **blue / teal / purple / amber** — decorative colour, which breaks design-law rules 1 and 3. Dead “Dosage Reminders” switch. “Support Development” heart in red.

Same tokens, same 16/24 radius, same type ramp, same hairlines. Manage becomes a quiet settings list, not a rainbow of Cards.

### 2. Bottom nav is generic and slightly dishonest

Four Material outline/fill icons, default grey inactive, cyan selected. Home’s botanical language dies at the chrome. Custom marks (leaf / chart / sliders) at one optical weight would lock the brand.

FAB sits at `bottom: 24` above a labelled 4-tab bar. On a tall phone that’s a dead band; on a short one it crowds Manage. Icon-only nav, or a slimmer bar, or dock the FAB into the bar.

### 3. Calendar chrome is loud for a week strip

`table_calendar` week, 58 px row + 22 px weekday labels + month + two cyan chevrons + Today pill. Cyan chevrons are decorative (rule 1). Presence is a 3×3 grey dot — easy to miss.

A custom 7-cell strip: day number, selected = filled accent disc, presence = hairline ring or tiny strain-coloured tick. Chevrons in tertiary grey. Same data, half the height, more vine below.

### 4. Vine density vs meaning

`VineRhythm` stretches 1–5 dose days to fill the viewport; gaps are **not** time-proportional. 18 m and 3 h 16 m get the same stem length; the number does all the work. On a 3-dose day the vine looks elegant and a bit empty. Options, pick one:

- slight time-weighted gaps (clamped), or
- keep equal gaps but drop `maxGap` 120 → ~64 so a short day doesn’t look sparse, or
- a faint hour tick in the gutter.

Amounts are 22 px / w700 in strain colour. Identity (code) is 14 px grey. Scan is “big numbers”; strain is secondary. Fine for logging, weak for rotation-at-a-glance. A 2–3 px strain hairline under the amount, or a quieter amount, would rebalance.

### 5. Empty past days drop the metaphor

Today-empty = young shoot + NOW. Past-empty = generic eco icon + “Add your first dose” (`lib/screens/home/home_empty_state.dart`). A rest day should still be a vine with no leaves — a bare stem and a small “rest” mark. Same grammar, no CTA that implies the day is broken.

### 6. Duplicate “time since”

Header: `3h 16m since last dose · 5g · 1 dose`. Vine gutter: `3h 16m` again, brighter. Intentional insurance. On a 1-dose day it reads as the same fact twice. Keep the live gutter; shorten the header to `5g · 1 dose` while the live gap is on screen.

### 7. Add-dose sheet is the best secondary surface — two nits

Picker is on-brand (rank, rest, in-stock partition). Details step is a tall form: amount, now-pill, date, time, notes, wide Save. After strain pick, most sessions want amount + Save. Collapse date/time/notes behind “Adjust time”; default `_openedAt` is already correct.

`+ Add New Strain` as a full-width cyan block under the list competes with the row tap. Text button, not a second primary.

### 8. Dead settings and missing useful ones

Stored but unused: `dailyLimit`, `measurementUnit`, `enableToleranceTracking`, reminder times. Shown but inert: notification switch. Hidden but useful: `performanceMode`.

Ship a real Reduce motion / Save battery toggle. Either implement a daily-limit hairline on the status line or delete the field. Don’t show a disabled reminder.

### 9. Light theme is a second-class port

Dark is designed. Light is inverted greys + elevation-2 cards + white nav with elevation 8. Vine hairline is a fixed warm off-white (`0xFFEDE6DC`) in both themes — right on black, chalky on `#F7FAFA`. If light stays, retune hairline/aura; if it doesn’t, say so and stop pretending.

### 10. Small interaction polish

- FAB long-press for Add Strain is invisible. A 2-second tooltip on first launch, or a strain action on the Strains tab only.
- Day swipe is already deferred-commit + `RepaintBoundary`. Adjacent week-chevron jumps a week with no motion related to the pager — a small horizontal settle would match the day slide.
- Strain stock chip + overflow on every row is busy. Swipe-to-stock, or chip only when out of stock.
- No haptics on day change / save success (add-dose already clicks). One light impact on log would make the vine feel physical.

---

## What not to do

- Do not add WorkManager “because dumpsys mentioned jobs.”
- Do not re-litigate the animation architecture (boundaries, `TickerMode`, `shouldRepaint` primitives). That’s sound.
- Do not put a 7-day range on Stats. The “no 7d” comment in `lib/screens/stats/stats_bundle.dart` is correct.
- Do not add network sync. The phone’s weak-cell note is irrelevant; this app has no modem work.

---

## Suggested order if a later pass happens

1. Cache live-tail path metrics + pause offscreen / Reduce motion toggle.
2. Replace FAB fullscreen blur.
3. Restyle Strains + Manage + nav onto `AppColors`.
4. Slim the week strip.
5. Day-indexed dose map + cheaper persist.
6. Empty rest-day vine + de-dupe the elapsed label.

(1)+(2) address the only performance signal that survived contact with the code. (3)+(4) are the look-and-feel gap you can see without a profiler.

---

## Key files

| Area | Path |
|---|---|
| Live tail / dash metrics | `lib/widgets/vine_painter.dart` |
| Leaf marks | `lib/widgets/strain_mark.dart` |
| Home pager, timer, FAB blur | `lib/screens/home_screen.dart` |
| Vine list + tickers | `lib/screens/home/home_dosage_list.dart` |
| Week strip | `lib/screens/home/home_calendar_section.dart` |
| Status line | `lib/screens/home/home_day_card.dart` |
| FAB | `lib/screens/home/home_fab_menu.dart` |
| Empty past day | `lib/screens/home/home_empty_state.dart` |
| State + persist | `lib/providers/kratom_provider.dart` |
| Tokens / motion / performanceMode | `lib/theme/app_theme.dart` |
| Dead settings fields | `lib/models/settings.dart` |
| Strains (off-system) | `lib/screens/strains_screen.dart` |
| Manage (off-system) | `lib/screens/manage_screen.dart` |
| Stats compute | `lib/screens/stats/stats_bundle.dart` |
| Add dose | `lib/widgets/add_dosage_form.dart` |
| Nav shell | `lib/main.dart` |
| Release manifest | `android/app/src/main/AndroidManifest.xml` |

---

## Second-opinion review — appended 2026-08-15 (ZCode)

Same `main` @ `e756ec9`, evaluated against the phone report and this document. Verdict
first: the core perf diagnosis (the vine animation, not a background job) is correct,
and the Strains/Manage design critique is accurate — those stand. Below: corrections,
missed ideas, and YAGNI pushback. Items marked ✅ were implemented the same day in the
README's "Polish pass — 2026-08-15"; the rest are left as ideas or rejected.

### Corrections to this document

1. **"three `ui.Gradient.linear` shaders per segment" (Performance §5)** — it is two
   per `paintVinePath` call (aura + core; the hairline is a solid colour), so four
   gradients per dose row. The memoization recommendation stands; the stated cost is
   about a third high.
2. **"No haptics on day change" (Look and feel §10)** — calendar day taps already fire
   `selectionClick` (`home_calendar_section.dart:44`). Only the pager *swipe* lacks one.
3. **FAB blur framing (Performance §2)** — the blur mounts only while the radial menu
   is open (`_fabOpen`), so it is a transient burst, not a standing cost. The blur most
   worth deleting was missed entirely — see item 5.

### Missed ideas

4. ✅ **Undo on dose delete.** Deleting was 3 taps + 2 modal layers, and the "Dose
   deleted" snackbar already existed with no action on it. Undo re-adds the dose at
   its original timestamp (fresh ID — nothing keys on dose IDs); the confirm dialog
   is gone. Guarded for the strain-also-deleted-during-the-bar edge case.
5. ✅ **Strain-edit sheet blur** (`strains_screen.dart:321`): a sigma-5
   `BackdropFilter` over the *whole* sheet for the *entire* edit session — stronger
   and longer-lived than the FAB blur flagged in §2, and nearly invisible behind an
   ~85%-opaque container. Deleted; the sheet now matches the file's own options sheet.
6. ✅ **Dead code**: `lib/services/mobile_backup_service.dart` and
   `web_backup_service.dart` both define `BackupFileService` and are imported nowhere
   (Manage does its backup inline). Deleted. Related dead surface left alone:
   `ImportMode.merge` is unreachable from the UI — restore always replaces, which is
   fine for a single user.
7. ✅ **Cold start flashed light into a near-black app.** `launch_background.xml` was
   `@android:color/white` with no night variant, and `windowSplashScreenBackground`
   was unset (Android 12+ then follows the theme's `colorBackground`). Launch and
   normal windows are now pinned to the scaffold `#090B0C`.
8. ✅ **CI shipped a fat universal APK** — four engine copies for one arm64 phone.
   Now `--split-per-abi`; arm64 keeps the plain release filename so release
   consumers see no change.
9. ✅ **Dash caching (Performance §1), sharpened.** The dash cycle is 2+7 = 9px and
   the tail drifts 36px/2.8s ≈ 0.2px per vsync at 120Hz, so quantizing the phase to
   whole pixels needs only **9 cached dashed paths per geometry** (24 growth steps
   for the sprout — deterministic per loop) with imperceptible stepping. No shader or
   atlas machinery needed. Bonus the original idea missed: quantized offsets flow
   into `shouldRepaint`, so frames between phase steps skip the *raster* too — ~13
   repaints/s instead of ~120, not just cheaper CPU per frame.

### YAGNI pushback on this document's ranking

10. **Day-indexed dose map (§3) and incremental persist (§4) — defer.** At ~4–6
    doses/day the full scan is over ~2k records/year, sub-millisecond; the
    triple-write persist is kernel noise, not a felt cost. Build them the day Stats
    first-open or day-swipe actually hitches. Same for the stats isolate (§7) —
    already memoized per (range, mutationStamp).
11. **`performanceMode` Manage toggle (§6) — skip.** With §9 landed it would toggle
    off a cost that no longer exists.
12. **Light-theme retune (Look and feel §9) — skip.** Single user, dark in practice;
    the "system" theme mode that would make it matter gains nothing here.

### Phone report, second opinion

The 2.4× background/foreground attribution stays rebutted: no services, no alarms,
tickers auto-mute when hidden, the minute timer stops in `paused/hidden/detached`.
The plugged-in screen-off drain is consistent with engine/Play attribution plus a
concurrent AI-agent app on a trickle charge — a dirty window. The ~2.2-core foreground
bursts map to the two repeating live-tail tickers plus the sprout `saveLayer`; §9
removes the per-frame metric rebuilds. The sprout's `saveLayer` (10% of a 3.4s cycle,
empty-today only) was left as-is deliberately. `org.kratomtracker.app` on the device
is legacy 1.0 (README §Legacy 1.0 migration) — device hygiene, not app work.
