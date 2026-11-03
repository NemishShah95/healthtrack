# Build Status

_Last updated: 2026-11-01_

## Current Milestone
M18, Personal installation: **complete.** Installed on the product owner's iPhone 16 Pro on 2026-11-01 (from the work Mac, with their personal Apple Account).
Next: M19, real data validation against Apple Health.

## On the iPhone
| Item | Value |
| --- | --- |
| Device | iPhone 16 Pro |
| Signing | Free Personal Team; HealthKit entitlement granted |
| Signing expires | **2026-11-07 20:01 UTC** = Sun 8 Nov 00:01 Dubai time (UTC+4). Refresh on or before **Sat 7 Nov** |
| Database | `SchemaV1` is **frozen**: `schemaV1IsFrozen` fails on any in-place change |

## Build
iOS app (`xcodebuild`, iOS 27.2 simulator SDK): PASS, 0 warnings
Logic + database (`swift test`): PASS

## Tests
`swift test`: 70 passed, 0 failed (core logic, SwiftData, mock HealthKit, day records, export files, gym/protein)
Simulator (`xcodebuild test -parallel-testing-enabled NO`, iPhone 17, iOS 27.2): 77 passed, 0 failed, 1 skipped (70 unit + 7 UI incl. accessibility audit; the screenshot tour runs on request)

## Simulator QA
- [x] iPhone 17, light mode, 90 days of data: every screen reviewed; Sleep detail row height bug fixed
- [x] iPhone 17e (smallest), dark mode, accessibility-large text: tiles go single-column; two truncations fixed
- [x] iPhone 18 Pro Max with 90 days of data
- [x] Brand-new install (empty states): fixed meals showing "skipped" before the first log
- [x] Apple accessibility audit on every tab: fixed tile tap targets (tiles are now single buttons), contrast (accessible palette, dark text on pills), placeholders, clipping

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
| Tabs | Today · Trends · Weekly · Settings. **The Log tab was removed** (product owner, 2026-10-31); logging lives on the Today tiles and their pages |
| Today | Minimal tiles (one value + at most one action, tap for details), plus the last 5 days via a date strip or swipe for back-filling |
| Look | Minimal (Zomato-like calm), green accent, app icon = consistency ring + check |
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
- [x] M16 Full QA (simulator)
- [x] M17 Transfer package: fresh clone from GitHub passes `swift test` and builds for simulator and device; no machine-specific paths
- [x] M18 Installed on iPhone 16 Pro (2026-11-01)
- [ ] M19 Real data validation

## Known Issues
- With 8 tiles, Today scrolls slightly on a 6.3" iPhone (Steps and Check-in sit just below the fold).
- Simulator tests run with `-parallel-testing-enabled NO`; parallel device clones failed once with low disk space.

## Next Action
M19: compare HealthTrack with the Apple Health app (sleep, deep, REM, HRV, resting HR, steps, latest workout) once a night of real data has synced.
Refresh before 2026-11-07 from any Mac signed in with the **same** Apple Account. Don't delete the app.

Notes from the install: the work Mac's login keychain was reset during setup (the old file is kept as `login_renamed_1.keychain-db`); the first development certificate was revoked and a new one created.
