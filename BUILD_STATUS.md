# Build Status

_Last updated: 2026-10-31_

## Current Milestone
M1–M15 implemented. **Simulator QA (launch, visual checks, UI tests) waits for the iOS 27.2 Simulator download.**

## Build
iOS app (`xcodebuild`, iOS 27.2 simulator SDK): PASS, 0 warnings
Logic + database (`swift test`): PASS

## Tests
`swift test`: 57 passed, 0 failed (core logic, SwiftData, mock HealthKit, day records, export files)
UI launch test: written, not yet run (needs the simulator)

## Simulator QA
Pending (iOS 27.2 Simulator runtime downloading in Xcode)

## Environment (development Mac)

| Item | Finding |
| --- | --- |
| Hardware | Apple M4 Pro |
| macOS | 26.6.2 (25G83) |
| Xcode | 27.2 (27B52) at /Applications/Xcode.app. `xcode-select` still points at Command Line Tools, so commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (no admin needed) |
| iOS SDK | 27.2 (device and simulator) |
| iOS Simulator runtime | Downloading (iOS 27.2) |
| Command Line Tools | 16.4 (Swift 6.1.2) |
| Git | 2.39.5 |
| Xcode signing teams | None, and none needed: simulator builds sign locally; signing happens on the personal Mac |
| Free disk space | ~23 GB (95% used) |

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
- [ ] M16 Full QA (simulator)
- [ ] M17 Transfer package
- [ ] M18 Personal Mac installation (product owner)
- [ ] M19 Real data validation

## Known Issues
- None known. Visual QA has not happened yet.

## Next Action
When the iOS 27.2 Simulator finishes downloading: launch in the simulator, run the UI tests, visually check every tab
(light/dark, small/large iPhone, Dynamic Type, empty and 90-day states), then fix anything that clips.
