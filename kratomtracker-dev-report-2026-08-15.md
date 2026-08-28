---
document: Kratom Tracker Plus — Device Performance Report
date_captured: 2026-08-15, 20:16–20:53 local (single session sample)
prepared_for: app developer (owner)
method: read-only ADB diagnostics (dumpsys cpuinfo / batterystats / jobscheduler / alarm / activity services / pm dump / ps / top)
device_context: OnePlus 12 (CPH2581), OxygenOS 16.0.9.400 (Android 16, SDK 36), Snapdragon 8 Gen 3, 24 GB RAM, 120 Hz display
caveats: single session; app in active foreground use part of the time; device concurrently running an unrelated AI-agent app; phone trickle-charging from a laptop USB port (10 W) during capture
---

# Kratom Tracker Plus — Device Performance Report

## 1. Executive summary

Battery impact is negligible: **0.916 mAh of a computed 1,459 mAh device drain since last charge (0.06%)**. The app is well-behaved in the ways that usually go wrong: release build, current targetSdk, no AlarmManager entries, no leaked services.

Two findings deserve code attention:

1. **Foreground bursts reaching ~2.2 full CPU cores** during interaction (average across the session was a modest ~7% of one core — the problem is spikiness, not average load).
2. **Background CPU is 2.4× foreground CPU** (5m54s vs 2m30s), half the app's total drain occurring while *plugged in with the screen off* — pointing at job/worker work whose cost exceeds all user-visible activity combined.

Neither is a battery emergency. Both are cheap to fix if addressed.

## 2. Build under test (live facts)

| Property | Value |
|---|---|
| Package | `org.kratomtracker.plus` (uid u0a601) |
| Version | 2.16.1 (versionCode 20) |
| SDK | minSdk 24, targetSdk 36 |
| Build type | **Release** (pkgFlags lack DEBUGGABLE — numbers are not debug-inflated) |
| Installed | 2026-08-10 23:24 |
| Last updated | 2026-08-14 13:18 |
| Also on device | old package `org.kratomtracker.app` (u0a400), package-inactive since 20:11 |

## 3. Measured data

### 3.1 Session timeline

- Process started **20:16:25** (PID 18102), left foreground / torn down **20:53:57** → ~37-minute session.
- At 20:50 the app held **zero ServiceRecords** (dumpsys activity services) and **zero AlarmManager entries** (dumpsys alarm).
- **6 references in the JobScheduler dump** — the app does schedule background jobs.
- Standby bucket at check: 10 (ACTIVE) — consistent with recent foreground use, not a finding.

### 3.2 Foreground CPU — the bursts

`dumpsys cpuinfo` window 20:47:10→20:48:51 (~100 s):

```text
28% 18102/org.kratomtracker.plus: 21% user + 6.7% kernel / faults: 14929 minor
16% surfaceflinger
12% crtc_commit (kernel)
 8.6% vendor.qti.hardware.display.composer-service
 8.2% system_server
```

Important calibration: `dumpsys cpuinfo` percentages are **shares of total device CPU capacity** (800% across 8 cores). 28% ≈ **2.2 cores sustained** — the single largest consumer on the device during the window, above the entire display stack. Over the full session the app averaged only ~7% of one core (2m30s foreground CPU), so the cost is concentrated in interaction bursts.

Kernel share (6.7 of 28 points) is notable — syscall/IPC-heavy work (I/O, binder, page faults), not pure computation.

### 3.3 Page faults

14,929 minor faults per ~100 s window ≈ 150/s. For scale, SystemUI logged 20,853 in the same window — so this is **moderate, not alarming**. Worth a glance only if the UI also janks: check bitmap/list recycling and per-frame allocations.

### 3.4 Background vs foreground — the architectural finding

Battery attribution (dumpsys batterystats, since last charge):

```text
UID u0a601: 0.916 mAh total
  foreground: 0.349 mAh (2m30s CPU)
  background: 0.565 mAh (5m54s CPU)   ← 2.4× the foreground cost
  cached:     0.001 mAh
  (not on battery, screen off/doze): cpu 0.501 mAh, all background
```

Interpretation: the app does **more computing when the user isn't looking at it than when they are**, with the drain concentrated in *plugged-in, screen-off* periods. With no services and no alarms, the suspects are:

- JobScheduler/WorkManager periodic jobs (the 6 dump references) — if these are deliberate charge-constrained backups, the *pattern* is actually good design; verify the work is bounded, not a poll loop;
- a coroutine scope or Handler/timer tied to a long-lived object (Application, singleton, repository) that keeps collecting/emitting after `onStop`.

### 3.5 Network note (device-specific)

At 20:45:33 the battery history tagged the app `+top` during a transient `cellular_high_tx_power` event; the following PowerDetails snapshots show zero modem TX time, so it was momentary. Context: this particular phone sits on a **weak cell (−103 dBm)** where every network operation costs disproportionate heat. Any sync the app performs at open/in-background is more expensive on this device than typical — batching or deferring to charging + unmetered constraints pays off here.

## 4. What's already good

- Release build, not debuggable.
- targetSdk 36 (current).
- No AlarmManager abuse, no stuck services, cached-state CPU ≈ zero (2.6 s).
- Absolute battery footprint: 0.06% of device drain.

## 5. Recommended investigation checklist (in order)

1. **Profile one interaction burst.** With the app open and being used:
   ```bash
   adb shell simpleperf record -p $(adb shell pidof org.kratomtracker.plus) \
     -f 500 --duration 60 -o /data/local/tmp/kt.data
   adb shell simpleperf report -i /data/local/tmp/kt.data | head -40
   ```
   This names the hot threads/methods directly. (Perfetto GUI trace is the deeper alternative.)
2. **Audit WorkManager jobs:** list every periodic job, its constraints (`setRequiresCharging`, `setRequiredNetworkType UNMETERED`, `setRequiresBatteryNotLow`), and measure one run's wall/CPU time. Confirm the plugged-in burn is these jobs, bounded.
3. **Check scope lifecycles:** anything collecting flows/timers in an Application-level or singleton scope that only the UI needs — move to a lifecycle-aware scope cancelled in `onStop`.
4. **If Compose:** recomposition audit for the burst path (stable/immutable parameters, keyed lazy lists, `derivedStateOf` for derived reads, charts not redrawing per frame).
5. **If any live "time since dose" UI:** one shared 1 Hz ticker feeding all consumers — never a ticker per item/composable.
6. **Optional controlled run:** `adb shell dumpsys batterystats --reset` (clears stats — harmless but do it deliberately), use the app for 15 min, then capture the per-uid section for a clean before/after comparison.

## 6. Reproducing the measurements

```bash
# windowed per-process CPU (percentages = share of total capacity)
adb shell dumpsys cpuinfo | head -35

# per-uid battery attribution (fg/bg/cached split)
adb shell dumpsys batterystats | grep -A6 "UID u0a601"

# scheduled work
adb shell dumpsys jobscheduler | grep -iE "kratomtracker" | head
adb shell dumpsys activity services -p org.kratomtracker.plus
adb shell dumpsys alarm | grep -ic kratomtracker
```

## 7. Bottom line

The app is a good citizen by the numbers that matter most. Fix-worthy: identify what runs during interaction bursts (~2.2 cores), and either bound or embrace the background jobs that out-cost the foreground — the data suggests both are findable in under an hour with the simpleperf + jobscheduler pass above.
