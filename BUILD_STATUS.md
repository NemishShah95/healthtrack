# Build Status

_Last updated: 2026-11-07_

## Current Milestone
M18, Personal installation: **complete.** Installed on the product owner's iPhone 16 Pro on 2026-11-01 (with their personal Apple Account).
Next: M19, real data validation against Apple Health.

## On the iPhone
| Item | Value |
| --- | --- |
| Device | iPhone 16 Pro |
| Signing | Free Personal Team; HealthKit entitlement granted |
| Signing expires | **2026-11-14 09:22 UTC** = Sat 14 Nov 13:22 Dubai time (UTC+4). Refresh on or before **Fri 13 Nov**. Refreshed 2026-11-07 |
| Database | `SchemaV1` is **frozen**: `schemaV1IsFrozen` fails on any in-place change |

## Build
iOS app (`xcodebuild`, iOS 27.2 simulator SDK): PASS, 0 warnings
Logic + database (`swift test`): PASS (locally, and on GitHub Actions after every push)

## Tests
`swift test`: 81 passed, 0 failed (core logic, SwiftData, mock HealthKit, day records, export files, gym/protein, usual range, sync check, training goals, weekly experiment)
Simulator (`xcodebuild test -parallel-testing-enabled NO`, iPhone 17, iOS 27.2): 81 unit + 8 UI passed, 1 skipped (the screenshot tour runs on request). UI tests include the accessibility audit and a training goal ticked off from a logged session

## Simulator QA
- [x] iPhone 17, light mode, 90 days of data: every screen reviewed; Sleep detail row height bug fixed
- [x] iPhone 17e (smallest), dark mode, accessibility-large text: tiles go single-column; two truncations fixed
- [x] iPhone 18 Pro Max with 90 days of data
- [x] Brand-new install (empty states): fixed meals showing "skipped" before the first log
- [x] Apple accessibility audit on every tab: fixed tile tap targets (tiles are now single buttons), contrast (accessible palette, dark text on pills), placeholders, clipping
- [x] 2026-11-07 dark redesign: every screen reviewed on iPhone 17; iPhone 17e at normal and accessibility-large text. Fixed: translucent cards (audit can't measure through them, now opaque), squeezed Consistency label, stretched Apple Health rows in Settings, dropdown rows only tappable on their text

## Environment (development Mac)

| Item | Finding |
| --- | --- |
| Hardware | Apple M4 Pro |
| macOS | 26.6.2 (25G83) |
| Xcode | 27.2 (27B52), selected with `xcode-select`. Xcode 27's simulator window is the **DeviceHub** app |
| iOS SDK | 27.2 (device and simulator) |
| iOS Simulator runtime | iOS 27.2 (iPhone 17, 17e, Air, 18 Pro, 18 Pro Max) |
| Command Line Tools | 16.4 (Swift 6.1.2) |
| Git | 2.39.5 |
| Xcode signing teams | None, and none needed: simulator builds sign locally; signing happens on the personal Mac |
| Free disk space | ~11 GB (98% used). Risky below ~5 GB |

## Decisions

| Decision | Value |
| --- | --- |
| Project location | `~/Documents/healthjournal` (product owner's choice) |
| Git | Private GitHub repo `NemishShah95/healthtrack` via SSH alias `github-personal`, with a personal identity set for this repo. Never GitLab |
| Bundle identifier | `com.nemishshah.healthtrack` (permanent) |
| Deployment target | iOS 17.0 |
| Swift language mode | Swift 5 |
| HealthKit read types | Sleep, resting HR, HRV, steps, active energy, workouts. Only what the app shows |
| Simulator Health data | Deterministic mock (`-mockHealth <scenario>`), because the simulator has no Health data |
| Schema | `SchemaV1`, still editable until the first install on the iPhone (M18), frozen afterwards |
| Tabs | Today · Training · Trends · Weekly · Settings. **The Log tab was removed** (product owner, 2026-10-31); logging lives on the Today tiles and their pages |
| Today | Bento cards (one value + at most one action, tap for details), plus the last 7 days via the week strip or swipe for back-filling |
| Look | Dark-only redesign (2026-11-07) from the product owner's design: navy-to-teal gradient, opaque dark cards, light-weight numbers, lime accents, teal for sleep. Full spec in README → Design |
| Input | Dropdowns for every choice (product owner, 2026-11-07); typing only for notes and "Other…" names. One-tap buttons stay |
| Training | A Training tab: goals per exercise (distance, sets × reps, weight or time), weekly (1–7×) or one-off milestones; met by gym-journal entries. Stored in `Goals` (no schema change) |
| Licence | MIT for the code. Design, app icon and logo excluded: © Nemish Shah, all rights reserved (TRADEMARKS.md) |
| App icon | Lime habit ring around a teal crescent moon on navy (2026-11-07), drawn by `Design/make-icon.py`; replaces the first green ring-and-tick icon |
| Gym journal | Focus chips + exercises one per line ("Squat 5x5 100 kg", "Treadmill 20 min 3 km"); counts as a workout without double counting the watch |
| Protein | Daily counter (+10/+20/+30 g), user-set target (default 100 g), not part of the consistency score |
| Devices | iOS 17+, so iPhone 16 Pro (product owner), 17 and 17 Pro; all the same size as the tested iPhone 17 |

## Features
- [x] M0 Repository, docs, environment
- [x] M1 Xcode project, five tabs (build ✓; simulator launch pending)
- [x] M2 SwiftData persistence: CRUD, reopen-preserves-data, idempotent import (simulator restart check pending)
- [x] M3 HealthKit abstraction: live provider, mock with 6 scenarios, onboarding and permission handling
- [x] M4 Sleep and recovery: aggregation, Today sleep card, HRV/RHR versus your 30-day baseline
- [x] M5 Meals: one-tap, foods with grams, recent and favourite foods, usual meals, repeat, edit, delete, history
- [x] M6 Water: +250/+500/+750/custom, double-tap guard, undo, target
- [x] M7 Supplements: add/edit/pause, weekday schedules, taken/skipped/missed, reminders, adherence
- [x] M8 Activity: steps, workouts, weekly target
- [x] M9 Today dashboard (visual QA pending)
- [x] M10 Behaviour score
- [x] M11 Trends: 13 charts, 7/30/90 days (visual QA pending)
- [x] M12 Weekly review with week navigation
- [x] M13 Insights with sample thresholds
- [x] M14 Reinstall reminder: detection, profile expiry, banner, Settings → App Installation, refresh notification
- [x] M15 Export (all/JSON/CSV zip, share sheet, last export date) and JSON restore
- [x] Added: gym journal (sessions, focus, exercises, repeat last, history, body-part focus chart) and protein tracking
- [x] Added (2026-11-03): vitamin journal + "as needed" vitamins; Vitamins tile always visible (was hidden until set up). No schema change
- [x] Added (2026-11-07), ideas from Helios (MIT): usual-range baselines (median ± MAD), watch sync check, backup-copy check, Siri/Shortcuts logging, weekly experiment, GitHub Actions running `swift test`
- [x] Added (2026-11-07): dark redesign, dropdown inputs, Training tab with goals. No schema change
- [x] M16 Full QA (simulator)
- [x] M17 Transfer package: fresh clone from GitHub passes `swift test` and builds for simulator and device; no machine-specific paths
- [x] M18 Installed on iPhone 16 Pro (2026-11-01)
- [ ] M19 Real data validation

## Known Issues
- Today scrolls on a 6.3" iPhone: the Workouts list and the last tiles sit below the fold.
- In the simulator, "Failed to refresh AppShortcut parameters" is logged during tests (in-memory store, no Siri daemon). Check "Log Vitamin D in HealthTrack" on the iPhone.
- Simulator tests run with `-parallel-testing-enabled NO`; parallel device clones failed once with low disk space.

## Next Action
M19: compare HealthTrack with the Apple Health app (sleep, deep, REM, HRV, resting HR, steps, latest workout) once a night of real data has synced.
Refresh before **Fri 13 Nov** from any Mac signed in with the **same** Apple Account. Don't delete the app. If Xcode keeps the old expiry, see the note in [FREE_PROVISIONING_REFRESH.md](Documentation/FREE_PROVISIONING_REFRESH.md).

Notes from the install: the first development certificate was revoked and a new one created.

Notes from the 2026-11-07 refresh: Xcode had been signed out of the Apple Account, so builds silently reused the cached profile (same expiry). After signing back in, the cached profile was set aside and `xcodebuild -allowProvisioningUpdates` fetched a new one (expires 14 Nov).
