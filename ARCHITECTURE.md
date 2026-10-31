# Architecture

## Layers

```text
HealthTrack/
├── App/            App entry, tab bar, dependency wiring                   (M1)
├── Core/           Pure logic, Foundation only: no SwiftUI/SwiftData/HealthKit   ✅
├── Health/         HealthKit reading behind a protocol, plus a mock provider (M3)
├── Persistence/    SwiftData models, container, export/import service  (M2, M15)
├── Features/       Today · Log · Trends · Weekly · Settings (and their sub-screens)
└── Shared/         Reusable views, design tokens, chart helpers
```

Rules:

- **Views hold no business logic.** They call into `Core` with plain values.
- **`Core` imports only Foundation.** Both the app target and `Package.swift` compile it, so `swift test` covers it in about a second with no simulator.
- **Only HealthKit sits behind a protocol** (`HealthDataProvider`, with a live and a mock implementation). It's the one dependency the simulator can't supply. SwiftData isn't wrapped in a repository protocol; tests use an in-memory `ModelContainer` instead.
- No third-party packages. No networking code at all.

Deviations from the spec's suggested tree:

- `SleepAggregator` lives in `Core/`, not `Health/`. It works on plain `SleepSample` values, so it's testable without HealthKit.
- No separate `Repositories/` folder; see the rule above.

## Screens

Minimal by design: summary first, details one tap away, logging never more than one tap.

- **Today**: the date strip shows today and the previous 5 days (swipe or tap) so forgotten entries can be back-filled. Below it are the consistency ring and six tiles (Sleep, Water, Meals, Supplements, Steps, Check-in). Each tile shows one value and at most one quick action (+250, + Dinner, All ✓). Tapping anywhere else opens that day's full page.
- **Trends**: one row per metric (summary + sparkline), grouped Sleep / Recovery / Activity / Habits. Tap a row for the full chart.
- **Weekly**: ring, best habit, what to watch, four key numbers. "Full breakdown" holds every number. The current week counts finished days only.
- **Settings**: goals, supplements, reminders, Apple Health status, Data & Backup, App Installation, Privacy.

Deviation from the spec: there is no **Log** tab (product owner's decision, 2026-10-31). Logging lives on the Today tiles and their pages.

## Source of truth

| Data | Owner | Notes |
| --- | --- | --- |
| Sleep, heart rate, resting HR, HRV, steps, workouts, active energy, distance, exercise time, weight, SpO₂ | **Apple Health (HealthKit)** | Read-only, queried on demand, never copied into SwiftData |
| Meals, food entries, saved meals, favourites, water, supplements, schedules, supplement logs, check-ins, goals, settings, reinstall metadata, export metadata | **SwiftData** (on device) | Included in JSON backups |

## Sleep methodology (`Core/SleepAggregator.swift`)

1. Asleep samples (core, deep, REM, unspecified) are grouped by source and merged into **sessions**. Gaps of 90 minutes or less stay in the same session.
2. A session belongs to the **night of the day you woke up**. Sessions ending at 18:00 or later count toward the next day.
3. Per source, only the **longest session** per night is kept, which drops naps.
4. Per night, **one source** is used: the one with stage data first, then the one with the most sleep. Sources are never added together, so overlapping devices can't double count.
5. Within that source, overlapping samples are merged, so each minute counts once.
   - total asleep = merged asleep time
   - awake = (final wake − sleep start) − asleep
   - interruptions = gaps of 1 minute or more between asleep periods
   - time in bed = sleep span ∪ any "in bed" samples overlapping it
   - deep/REM/core are `nil` when the source wrote no stages
6. Durations are real elapsed time, so DST nights come out as 9 h or 7 h correctly.

Stages are wearable estimates. The app never says more or less REM is "better". It shows trends against your own baseline.

## Behaviour (consistency) score (`Core/BehaviorScore.swift`)

"Did I do what I intended to do?" Physiology (HRV, resting HR, sleep stages) is **not** part of it.

| Component | Weight | Daily value, 0–1 | Left out when |
| --- | --- | --- | --- |
| Sleep routine | 25 | (bedtime within ±tolerance) + (wake time within ±tolerance) + (asleep ≥ target), ÷ 3 | no sleep data for last night |
| Meal routine | 20 | mean over breakfast/lunch/dinner: on time 1, early or late 0.5, skipped 0 | every meal still pending (its window hasn't ended) |
| Exercise | 20 | min(1, workouts in the last 7 days ÷ weekly target) | no workout data, or target 0 |
| Hydration | 15 | min(1, water ml ÷ target) | target 0 |
| Supplements | 10 | taken ÷ scheduled (skipped and missed count as not taken) | nothing scheduled |
| Daily movement | 10 | min(1, steps ÷ step target) | no step data, or target 0 |

**Score = Σ(weight × value) ÷ Σ(weight), over the components present.** Missing data never counts as failure. Logging nothing still counts: 0 ml of water is a value of 0. Weights are a parameter (`score(_:weights:)`), ready for user-configurable weights later.

Defaults: bedtime 23:00, wake 07:00, ±30 min, 7 h sleep, 2.5 L water, 8,000 steps, 4 workouts/week. Meal windows: breakfast 07:30–09:30, lunch 12:00–14:00, dinner 19:00–21:00. All are editable.

## Weekly review (`Core/WeeklyReview.swift`)

- Weeks follow the phone's calendar (first weekday from your locale).
- Consistency = mean of the daily scores.
- HRV and resting-HR trends compare this week's mean with last week's. A change within ±5% is "stable"; with fewer than 3 values per week no trend is shown.
- **Best habit** = the component with the highest weekly average.
- **Needs attention** = up to two other components averaging below 70%, lowest first.

## Insights (`Core/Trends.swift`)

Descriptive only. Wording is "was", "on nights when", "compared with"; tests reject causal or diagnostic words ("because", "leads to", "improve", "diagnos…").

| Insight | Minimum sample |
| --- | --- |
| Sleep on nights after early vs late dinner (cutoff 20:30) | 5 nights in **each** group, and a difference of at least 10 min |
| 30-day HRV vs the prior 30 days | 14 readings in **each** period |
| Bedtime target hit rate | 7 nights |
| Supplement logged X of Y days | 7 scheduled days |

## Meal timing and time zones

Each meal stores the time zone it was logged in. Window checks use that zone, so travelling doesn't retroactively make breakfast "late". Supplement schedules and sleep nights follow the phone's current calendar.

## Reinstall reminder (`Core/ReinstallSchedule.swift`)

- Next suggested refresh = last refresh + 6 days, moved earlier if the signing profile expires before then.
- Status: **due soon** within 2 calendar days, **due today** on or after the date.
- Refresh detection (M14): on launch, the app compares the executable's modification date with the stored value. If it changed, Xcode reinstalled the app, so `lastProvisioningRefreshDate` is set to now. The profile expiry is read from `embedded.mobileprovision` when present (not on the simulator).

## Backup format (`Core/Export.swift`)

- `ExportBundle` is versioned (`formatVersion`) and deliberately separate from the SwiftData schema, so old backups remain readable after model changes.
- Fields are only ever *added* (as optionals); anything else bumps the version.
- A backup from a newer app version is refused, not half-imported.
- `Goals` decoding fills missing keys with defaults.
- JSON is the restorable backup; CSV (one file per type) is for spreadsheets.
- Exported files are named `HealthTrack-Export-*`, a pattern `.gitignore` excludes.

## Schema changes (after V1)

See [DATA_SAFETY.md](DATA_SAFETY.md#safe-upgrade-procedure). Never rename or remove a persisted field casually. Use a `VersionedSchema` and `SchemaMigrationPlan`, and test against a populated store.
