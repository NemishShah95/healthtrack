# Build Status

_Last updated: 2026-10-31_

## Current Milestone
M16, Full QA: in progress. The minimal redesign is done (product owner's request, 2026-10-31).

## Build
iOS app (`xcodebuild`, iOS 27.2 simulator SDK): PASS, 0 warnings
Logic + database (`swift test`): PASS

## Tests
`swift test`: 58 passed, 0 failed (core logic, SwiftData, mock HealthKit, day records, export files)
Simulator (`xcodebuild test`, iPhone 17, iOS 27.2): 63 passed, 0 failed (58 unit + 4 UI smoke + screenshot tour)

## Simulator QA
- [x] iPhone 17, light mode, 90 days of data: every screen reviewed; Sleep detail row height bug fixed
- [x] iPhone 17e (smallest), dark mode, accessibility-large text: tiles go single-column; two truncations fixed
- [ ] iPhone 18 Pro Max, empty-state visual pass, VoiceOver spot check

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
| Free disk space | ~11 GB (98% used). Tight |

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
- [~] M16 Full QA (simulator): in progress, see Simulator QA above
- [ ] M17 Transfer package
- [ ] M18 Personal Mac installation (product owner)
- [ ] M19 Real data validation

## Known Issues
- None known.

## Next Action
Finish M16 (Pro Max, empty states, VoiceOver), then M17: fresh-clone build check and final docs.
