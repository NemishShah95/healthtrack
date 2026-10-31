# Test Plan

## How to run

| Suite | Command | Needs |
| --- | --- | --- |
| Logic, database, mock Health | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | Xcode installed (no simulator) |
| App unit + persistence tests | `xcodebuild test -scheme HealthTrack -destination 'platform=iOS Simulator,name=iPhone 17'` | Xcode + iOS Simulator |
| UI tests | same, `HealthTrackUITests` target | Xcode + iOS Simulator |

All tests use Swift Testing. Core tests pin the calendar to Europe/London (which has DST) or another named zone, so results don't depend on the machine.

## Unit test coverage (spec §31)

| Area | Status | Where |
| --- | --- | --- |
| Meal-window classification | ✅ | `RoutineTests` |
| Meal consistency | ✅ | `RoutineTests` |
| Food parsing, zero grams, 500 food items | ✅ | `RoutineTests` |
| Water totals and target | ✅ | `RoutineTests` |
| Rapid duplicate water taps | ✅ logic / ⏳ UI | `RoutineTests` |
| Supplement scheduling (weekdays, start/end, paused) | ✅ | `RoutineTests` |
| Supplement adherence, streak, most missed | ✅ | `RoutineTests` |
| Sleep-day assignment, cross-midnight, naps | ✅ | `SleepAggregatorTests` |
| No double counting (overlapping samples and sources) | ✅ | `SleepAggregatorTests` |
| Missing sleep stage data | ✅ | `SleepAggregatorTests` |
| Time-zone handling | ✅ | supplements, sleep |
| Daylight-saving boundaries | ✅ | sleep, week, reinstall, time of day |
| Behaviour score, missing components | ✅ | `ScoreAndReviewTests` |
| Weekly aggregation, week boundaries, partial data | ✅ | `ScoreAndReviewTests` |
| Trend comparison | ✅ | `ScoreAndReviewTests` |
| Insight sample thresholds, no causal language | ✅ | `ScoreAndReviewTests` |
| Reinstall reminder dates and warning states | ✅ | `ReinstallAndExportTests` |
| Export serialisation (JSON round trip, CSV parses) | ✅ | `ReinstallAndExportTests` |
| Old settings/backups decode (missing keys) | ✅ | `ReinstallAndExportTests` |
| SwiftData CRUD, cascade delete | ✅ | `PersistenceTests` |
| Reopening the store preserves records (relaunch/upgrade) | ✅ | `PersistenceTests` |
| Schema V1 → V2 migration | ⏳ when V2 exists | |
| JSON import restores records, no duplicates | ✅ | `PersistenceTests` |
| Export files written; CSV zipped | ✅ | `PersistenceTests` |
| Day records join logs + Health; no-access handling | ✅ | `DayRecordTests` |
| Sample 90-day data set | ✅ | `PersistenceTests` |
| Mock Health: full, empty, denied, partial, no stages, one day, deterministic | ✅ | `MockHealthTests` |

## Data-state scenarios (mock HealthKit provider, M3 onward)

No data · one day · 7 days · 30 days · 90 days · partial permissions · denied permissions · missing sleep stages · multiple workouts · missed vitamins · skipped meals · many food items · long supplement names.

## Simulator QA checklist (M16)

- [ ] Smallest supported iPhone (iPhone SE) and the largest (Pro Max)
- [ ] Light and Dark Mode
- [ ] Dynamic Type up to accessibility sizes, with no clipped text
- [ ] Empty states on every tab
- [ ] Long text: food names, notes, supplement names
- [ ] Many meal entries, many supplements
- [ ] 90-day trends render and scroll smoothly
- [ ] Data survives an app relaunch and a simulator restart
