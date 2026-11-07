# Test Plan

## How to run

| Suite | Command | Needs |
| --- | --- | --- |
| Logic, database, mock Health | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | Xcode installed (no simulator) |
| App unit + persistence tests | `xcodebuild test -scheme HealthTrack -destination 'platform=iOS Simulator,name=iPhone 17'` | Xcode + iOS Simulator |
| UI tests | same, `HealthTrackUITests` target (add `-parallel-testing-enabled NO` if clones fail): every tab empty and with 90 days of data, one-tap water, protein + gym logging from Today through the dropdowns, a training goal ticked off by a logged session, vitamins from an empty app (pick from the dropdown, mark taken, journal an extra dose), swipe back through the week, accessibility audit | Xcode + iOS Simulator |
| CI | `.github/workflows/tests.yml` runs `swift test` on every push and pull request | GitHub Actions, macOS runner |

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
| Exercise line parsing (sets×reps, kg/lb, min, km/mi/k), round trip, volume | ✅ | `GymTests` |
| Gym sessions: log, edit, repeat, suggestions, cascade delete | ✅ | `GymAndProteinTests` |
| Protein: range and double-tap guard | ✅ | `GymAndProteinTests` |
| Workouts counted once when watch + journal overlap | ✅ | `GymAndProteinTests` |
| Vitamin journal: taken, double-tap guard, excluded from adherence, starts tracking | ✅ | `VitaminJournalTests` |
| Switching a vitamin to "as needed" keeps history, drops pending doses | ✅ | `VitaminJournalTests` |
| SchemaV1 unchanged (freeze snapshot) | ✅ | `schemaV1IsFrozen` |
| Weekly gym/protein summary | ✅ | `ScoreAndReviewTests` |
| Usual range: 7-day minimum, robust to an odd night, 3% floor, excludes the day itself | ✅ | `TrainingAndBaselineTests` |
| Watch sync check: stale only after a day with nothing; message | ✅ | `TrainingAndBaselineTests` |
| Weekly experiment: weakest habit, none for an empty week, no causal words | ✅ | `TrainingAndBaselineTests` |
| Training goals: weakest-field progress, name matching, weekly days/streaks, milestones, stored in Goals, old goals decode | ✅ | `TrainingAndBaselineTests` |
| Exercise catalogue: kinds, ordering by body part, old values stay pickable | ✅ | `TrainingAndBaselineTests` |
| Recent exercises, training log, save/replace/delete training goals | ✅ | `GymAndProteinTests` |
| Taking a vitamin (Siri): ticks the open dose first, then journals, double log ignored | ✅ | `VitaminJournalTests` |
| Backups without gym/protein (older format) still decode | ✅ | `ReinstallAndExportTests` |
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

## Accessibility

`testAccessibilityAuditOnEveryTab` runs Apple's automated audit (VoiceOver labels, contrast, hit targets, clipped text) on every tab. Deliberately skipped, with reasons in the test:
- "Contrast nearly passed": Apple's own secondary-label grey, the same as in Apple's apps.
- Contrast on anything under the translucent tab bar: the audit measures through the blur.
- Contrast findings with no element attached: unattributable system chrome (logged, not failed).
- Contrast findings that **pass when measured**: the test crops the element from a screenshot and computes the WCAG ratio between its lightest and darkest pixels. At 4.5:1 or more the finding is a false positive. On the see-through gradient the audit flags list section headers whatever their colour (measured 15–21:1 on 2026-11-07).
- "Potentially inaccessible text" with no element: the glass tab bar shows a blurred copy of the rows behind it. A dump of the Settings tree showed every visible label in the accessibility tree.
- The Dynamic Type sub-check: it flags plain system list rows. Large text is checked visually (accessibility-large on iPhone 17e).

## Simulator QA checklist (M16)

- [x] Smallest available iPhone (17e) and largest (18 Pro Max)
- [x] Light and Dark Mode (dark-only since the 2026-11-07 redesign)
- [x] Dynamic Type at accessibility-large (two truncations fixed; redesign rechecked on iPhone 17e, single-column bento)
- [x] Empty states on every tab (brand-new install, screenshot tour `TEST_RUNNER_SCREENSHOTS=empty`)
- [ ] Long text: food names, notes, supplement names
- [ ] Many meal entries, many supplements
- [x] 90-day trends render
- [x] Data survives reopening the store (unit test)
