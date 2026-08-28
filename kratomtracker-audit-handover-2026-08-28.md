# KratomTracker — Deep Bug Audit & Fix Handover, 2026-08-28

Complete ledger of the deep bug audit run on 2026-08-28 (base: v2.16.2+21,
commit e756ec9), everything that was changed in the working tree, the
reasoning behind each change, and what is deliberately left for later.
Nothing is committed yet — every fix lives in the working tree, verified
with `flutter analyze` (0 issues) and `flutter test` (218/218 pass).

---

## Part 1 — What we discovered (full findings ledger)

The audit ran as four parallel deep-review passes (provider/data layer,
stats/report, forms/widgets/screens, infra/lifecycle/platform) plus a
manual verification pass on the home screen and calendar.

### The reported bugs

**B1. "Gets stuck in the past, won't jump to today by itself" — P1, root cause found.**
`lib/screens/home_screen.dart` mapped PageView index → day via
`addDays(DateTime.now(), index - _todayPage)`, evaluated at *build* time,
while the controller stayed parked on the page index it had. After the app
stayed alive past midnight (backgrounded on Android, or a left-open
desktop/web window):

1. The visible page kept rendering the day it was built for (yesterday).
2. Swiping built fresh pages against the shifted `now()`, so adjacent pages
   could show the same day and every swipe landed one day off.
3. **Today became unreachable**: it now corresponded to page 10001, but
   `itemCount: _todayPage + 1` caps the last index at 10000. Tapping the
   "Today" pill computed target 10001 → the scroll clamped back →
   `onPageChanged` never fired → header said today, list showed yesterday,
   and every later jump inherited the corrupt state. Only killing the
   HomeScreen state (app restart) escaped.
4. `provider.selectedDate` was only committed on swipe-settle, so it stayed
   on yesterday → the add-dose sheet seeded "log now" as *yesterday at the
   current time-of-day* — silent mis-dated data, the costliest consequence.

**B2. "Small refresh-rate issues" — P2, two mechanisms.**
(a) The minute `Timer.periodic` was phase-locked to app start, not the wall
clock: labels could lag 0–59 s ("now" could persist ~95 s after a dose) and
jumped more than one step after resume. (b) The live dashed vine tail is
quantized to whole-pixel dash phases (pre-existing `quantizeLiveDashOffset`),
which reads as visible 1 px stepping on 60/90 Hz panels (smooth at 120 Hz).

### Other findings, by severity

**P1 (wrong behavior, user-visible):**
- **Stats frozen past midnight** — `stats_screen.dart` memoized the stats
  bundle on `(range, mutationStamp)` with no date component and had no
  timer/lifecycle observer; an overnight session showed yesterday's windows,
  streaks and drift until a dose was logged or the range changed.
- **Support link dead on Android 11+** — `canLaunchUrl` needs a `<queries>`
  declaration (API 30+ package visibility); the manifest had none, so the
  Buy-me-a-coffee tap silently did nothing on every modern device.
- **Whitespace-only strain name/code passed form validation** (no `trim()`),
  then the provider threw `ArgumentError` on the un-awaited call → the
  sheet popped as if saved; nothing was created (add + edit strain forms).
- **"Log again now" double-tap race** — no re-entrancy guard → duplicate
  doses; a missing strain threw uncaught and dead-ended the sheet.

**P2 (data integrity):**
- Future-dated doses from an import corrupted streak/rest-day math on the
  stats "All" range (empty future tail counted as rest days).
- A corrupt stored JSON list degraded to `[]` with only a debugPrint; the
  next write made the loss permanent (no quarantine, no `.bak`).
- Unparseable dose timestamps decoded as the 1970 epoch and were re-persisted;
  the backup codec treated the same record as malformed (paths disagreed).
- Merge imports dropped doses whose strain was missing from the backup's own
  strain list even when the strain existed locally; legacy bare-list backups
  let orphan doses through (→ edit-dose dropdown assertion crash in debug).
- `clearAllData` reset settings to *different* defaults than a fresh install
  (re-enabled notifications, tolerance interval 7→30) and removed the user
  name outside the write chain, so a queued rename could resurrect it.

**P2 (UI/behavior):**
- Report screen: fire-and-forget update/delete with unconditional success
  UI; per-sheet `TextEditingController` never disposed; a day's doses
  rendered in insertion order, not time order.
- Time-of-day pickers were unclamped → future-dated doses "today" rendered
  as if just taken above the NOW node.
- Hardcoded `h:mm a` ignored the system 24-hour setting.
- Editing a strain with a non-palette color (possible via import) silently
  recolored it to Forest green on save.
- Delete-strain confirmation didn't warn it destroys the strain's entire
  dose history.
- Restore-backup force-unwrapped the picked file path (null path on
  web/cloud picks → error dialog).
- Bottom nav hard-overrode `Colors.grey` (~2.1:1 contrast on light theme),
  discarding the theme's tuned value.
- App startup `FutureBuilder` had no error branch — a platform-level prefs
  failure left the splash spinner up forever; `main()` had no error handling.
- Strains screen edit sheet ran a full-sheet `BackdropFilter` blur at sigma 5
  behind an ~opaque container — pure GPU cost (perf, pre-existing pass).

**P2 (build/CI):**
- Gradle keystore fail-fast covered only `assembleRelease`;
  `flutter build appbundle --release` could emit an unsigned AAB.
- Workflow: job-wide `contents: write` (applied to PR runs too), no
  tag↔pubspec version check, Flutter channel unpinned, fat APK shipped 4
  engine copies.

**P3 / cosmetic / latent:**
- Web manifest still said "A new Flutter project."
- `currentBackupVersion` declared in two places that could drift.
- Theil–Sen drift fit is O(n²) over whole history — a scaling ceiling at
  multi-year histories, not a present bug.
- CSV export: RFC 4180 quoting correct, but no formula-injection
  neutralization for `= + - @` prefixes in free-text fields.
- Test gap: no midnight-rollover test anywhere; the existing
  pause/resume home test never advanced the clock; `quantizeLiveDashOffset`
  had no unit tests.

**Verified NOT bugs** (checked, clean): DST-safe date utilities used
consistently in stats; model `==`/`hashCode` correct; `_save` temp-key crash
consistency; per-tick rebuild isolation (only label subtrees rebuild);
`withValues` everywhere (no deprecated `withOpacity`); uuid v4 IDs;
analytics empty-collection guards; rotation shares sum to 100%; backup
exclusion rules intentional; versions consistent across pubspec/kAppVersion/README.

---

## Part 2 — What we changed (change ledger + reasoning)

Transparency note: while fixes were being applied, the working tree came to
contain implementations of most of this list from a **parallel session
running at the same time**. Every diff was reviewed against the audit
findings line-by-line rather than re-applied; the review confirmed they are
correct, and the remaining gaps (marked **[this session]**) were completed
on top. All changes are uncommitted, and the whole tree passes
`flutter analyze` (0 issues) and `flutter test` (218 tests, including the
new midnight rollover test).

### The rollover family (fixes B1 + stats P1)

1. **`lib/screens/home_screen.dart` — anchored page mapping + wall-clock sync.**
   - New `DateTime _anchor` field: the day page `_todayPage` maps to, frozen
     at init. `_dateForPage` now derives from the anchor, so the index→date
     mapping can never shift under the user mid-session.
   - New `_syncToWallClock()`, called on the minute tick **and** on
     `AppLifecycleState.resumed`: updates the `_now` label clock; when the
     calendar day has changed it re-anchors, re-points `_focusedDay`, calls
     `setState` (page keys are day-granularity, so the today page rebuilds),
     jumps the pager back to `_todayPage`, and re-commits
     `provider.selectedDate` — the app now follows the real today by itself,
     and post-midnight doses are dated to the real today.
   - Timer rebuilt as a one-shot `Timer` armed to the **next wall-clock
     minute boundary** (`_delayUntilNextMinute`) instead of a drift-prone
     periodic timer from app start — fixes refresh lag mechanism (a).
   - `_selectDay` clamps its computed target into `[0, _todayPage]` and maps
     through the anchor, so a stale calendar frame can never desync the
     header from the pager again.
   - `_HomeDayPage` now receives `today: _anchor` instead of re-reading
     `DateTime.now()` per build, so "is this page today?" is consistent with
     the pager and calendar.
   - Added `clock` test seam (`@visibleForTesting`) so widget tests can
     drive the wall clock.
   - PageView got `key: Key('home-day-pager')` for tests.
   - *Trade-off:* on rollover the view snaps to today even if the user was
     browsing a past day at the time. Chosen deliberately — it's a daily-use
     tracker and the user's explicit ask was "jump to today by itself"; the
     alternative (preserving the browsed past day) is a small follow-up if
     it ever bothers anyone.

2. **`lib/screens/stats_screen.dart` — day-aware memo + midnight timer.**
   Bundle memo key is now `(range, stamp, day)`; the State gained a
   `WidgetsBindingObserver` (recompute on resume) and a self-re-arming timer
   that fires at the next local midnight. Overnight stats can no longer
   silently show yesterday's numbers.

3. **`test/screens/home_midnight_test.dart` — NEW.**
   Widget test that pumps HomeScreen with the injected clock at 23:59, walks
   the lifecycle paused→resumed into the next day, and asserts: selectedDate
   follows, the empty-today shoot appears, the controller stays on a valid
   page, and jumping back to a past day and tapping the new today in the
   week strip lands correctly. Closes the exact test gap that let B1 ship.

### Form/entry fixes

4. **`lib/widgets/add_strain_form.dart` + `edit_strain_form.dart` — trim
   validators + awaited saves.** Validators reject whitespace-only
   name/code; submit now awaits the provider call inside try/catch, pops
   only on success, and shows an error snackbar on failure. No more silent
   phantom-saves.

5. **`lib/screens/home/home_dose_actions.dart` — log-again guard.**
   `_logAgain` got a re-entrancy guard (`_isLoggingAgain`), a null-strain
   early exit with a snackbar, and try/catch around `addDosage`. (The
   delete-with-undo flow pre-dates this pass.)

6. **`lib/widgets/add_dosage_form.dart` — seed semantics.**
   `_seedDateTime` now treats any selected day at-or-after the open day as
   "today" (seeds `openedAt` exactly); only a genuinely past selected day
   keeps the day with the open time-of-day. Uses the DST-safe `startOfDay`.

7. **`[this session]` Future-time guard (add + edit dose forms).**
   Both `_submit` and `_save` reject a timestamp in the future with a
   "Dose time is in the future" snackbar — the date picker clamps to today
   but the time wheel never did, and the vine rendered future doses as if
   just taken.

### Provider / data integrity

8. **`lib/providers/kratom_provider.dart`:**
   - `clearAllData` resets to the same defaults a fresh install produces
     (`enableNotifications: false`, `toleranceBreakInterval: 7`).
   - User-name removal moved inside `_enqueueWrite`, so a queued rename can
     no longer resurrect the name after "clear all".
   - Corrupt stored lists are **quarantined** under
     `_kratom_tracker_quarantine_<key>` before any mutation can overwrite
     them; per-item malformed records and orphan doses (strain missing) are
     detected and quarantine the blob too. Load can no longer silently
     amplify corruption into permanent data loss.
   - Import validation now rejects doses referencing unknown strains in
     both modes; merge mode re-resolves the backup's *orphaned* doses
     against the merged strain set, so doses recoverable after merge are no
     longer dropped at parse time.
   - Removed the duplicate `currentBackupVersion` (single source of truth in
     the codec).

9. **`lib/models/dosage.dart` — no more epoch fallback.** `fromJson` throws
   `FormatException` on an unparseable timestamp; `_decodeList`'s per-item
   catch skips it, matching the backup codec's definition of malformed. No
   1970 ghosts in stats.

10. **`lib/data/backup_codec.dart` — orphan doses preserved in the payload**
    (`BackupPayload.orphanedDosages`) so the provider can resolve them in
    merge mode (see 8).

11. **`lib/domain/analytics_service.dart` — future-proof stats.**
    `computeDoseStats` clamps the requested range to today before seeding
    day buckets, so future-dated imports can no longer zero the current
    streak or inflate rest-day counts on the "All" range.

### Screen-level fixes

12. **`lib/screens/report_screen.dart` — real async edit/delete.**
    The edit sheet is now a proper StatefulWidget (`_EditDoseSheet`) with a
    disposed controller, awaited `updateDosage`/`deleteDosage` inside
    try/catch, success UI only after the write, and errors surfaced. A
    day's dose cards are sorted chronologically after grouping.

13. **`lib/screens/manage_screen.dart`:**
    Support link dropped the `canLaunchUrl` gate in favor of
    `launchUrl` + catch (url_launcher's documented recommendation, works on
    Android 11+ regardless of package visibility). Restore-backup checks
    the picked file path for null with a friendly error instead of `!`.

14. **`lib/screens/strains_screen.dart`:** delete confirmation now states it
    permanently deletes ALL recorded doses for the strain; edit sheet's
    pointless full-sheet backdrop blur removed (opaque container + GPU cost).

15. **`lib/main.dart`:** startup `FutureBuilder` gained an error branch
    (`_ErrorScreen`) so a prefs-level failure shows a message instead of an
    infinite splash spinner; removed the `Colors.grey` unselected-item
    override so the theme's tuned, WCAG-passing color applies.

16. **`lib/widgets/edit_strain_form.dart` — non-palette colors preserved.**
    A strain color outside the 12-swatch palette (via import) is kept via a
    `_CustomColorOption`; saving without picking a swatch no longer
    silently recolors the strain.

17. **`lib/screens/home/home_dosage_list.dart` + `vine_painter.dart`**
    (pre-existing pass, retained): live dash offsets quantized to whole-pixel
    phases with repaint skipping between steps — the refresh-smoothness work
    on the vine tail (mechanism (b) of B2 is inherent to quantization on
    60/90 Hz panels; the quantization bounds the repaint cost).

### Platform / CI

18. **`android/app/src/main/AndroidManifest.xml` — added `<queries>`** for
    the https VIEW intent, restoring `canLaunchUrl`/browser resolution on
    Android 11+ (belt to change 13's braces).

19. **`android/app/build.gradle` — keystore fail-fast now also covers
    `bundleRelease`**, so `flutter build appbundle --release` can't emit an
    unsigned AAB.

20. **`.github/workflows/main.yml`:**
    Flutter pinned to `3.44.9`; release build switched to
    `--split-per-abi` (arm64 stays the plain `-release.apk` name, other ABIs
    ride along) — ~4× smaller download for the single-arm64 phone case;
    added a tag↔pubspec version verification step ahead of the release
    attach; **[this session]** permissions narrowed to `contents: read` at
    job level with `contents: write` only on the release-attach step, so PR
    runs no longer hold a write token.

21. **`[this session]` `lib/export/csv_export.dart` — CSV formula-injection
    neutralization (OWASP).** Free-text fields (strain code/name/notes)
    starting with `= + - @`, tab, or CR are prefixed with `'` so Excel /
    Sheets render them as text instead of executing them. Amounts and dates
    are app-formatted and safe.

22. **`web/manifest.json` — template description replaced** with a real one.

### Pre-existing working-tree changes retained (not from this audit)

Android launch/theme color resources, README updates, and the deleted
`lib/services/mobile_backup_service.dart` / `web_backup_service.dart`
(superseded by the in-app backup codec path) were already in progress before
this audit began and are unchanged by it.

---

## Part 3 — What is left (deliberate deferrals, with directions)

1. **Locale-aware time format (P3).** `h:mm a` is hardcoded in the add/edit
   dose chips and home dose rows; 24h-locale users see 12h. Fix:
   `DateFormat.jm()` or `alwaysUse24HourFormat` branch. Touches several
   golden-ish widget tests; do it as its own pass.
2. **Theil–Sen O(n²) scaling (P3).** For multi-year histories the drift fit
   grows quadratically (≈4.8M pair evaluations at ~1,800 days × 3 fits per
   stats entry). Fix: cap the fit window at the most recent ~180 closed days
   (drift is defined as a recent-trend readout) or decimate before fitting.
3. **Stale "last used"-style labels on Strains (P3).** Per-build
   `DateTime.now()` reads (e.g. relative "last used" text) go stale in an
   open-overnight session until a rebuild. Low impact; fix alongside the
   day-rollover notifier if one gets extracted for shared use.
4. **`quantizeLiveDashOffset` unit tests (P3).** The trickiest new math has
   no direct tests (edge phases, negative offsets, 8→0 wrap). Small,
   self-contained.
5. **Delete-strain: offer "keep doses, unassign strain" (P3).** The warning
   copy is now honest, but the destructive default could offer a
   soft-delete/unassign path for strains with long histories.
6. **Import validator parity (P3).** `previewImport` accepts amounts the
   commit-time validator rejects (>1000 g), producing a preview-then-fail
   for third-party backups. Fix: run `_validatePayload` inside the preview.
7. **12h/24h + `DropdownButton` value guard (P3).** If an orphan dose ever
   reaches the edit-dose dropdown again, fall back to a synthetic
   "Unknown strain" item rather than relying on the import guards added in
   change 8.
8. **CI note.** `subosito/flutter-action` now pins 3.44.9; when bumping
   Flutter, bump the pin deliberately. The version-verify step runs only on
   tag pushes by design.
9. **Uncommitted tree.** Everything above is working-tree only. Suggested
   commit split: (a) rollover family + midnight test, (b) form/provider
   data-integrity fixes, (c) report/manage/strains UI fixes, (d) CSV +
   workflow + manifest/platform. Then bump to 2.16.3+22 and tag.

## Verification

- `flutter analyze` → No issues found.
- `flutter test` → 218/218 passed, including the new
  `test/screens/home_midnight_test.dart` rollover test.
- APK build not run locally (CI covers it; keystore guard now applies to
  both APK and AAB paths).
