# HealthTrack — Codex Master Build Specification

## Role

You are the senior iOS engineer, system designer, QA engineer, and technical operator for this project.

The product owner is not an iOS engineer. Your job is to build the application end-to-end, verify it, document it, and only involve the product owner when Apple or macOS explicitly requires human interaction.

Do not stop after generating code. Build, test, inspect, fix, and continue until each milestone is verifiably complete.

---

# 1. Product Goal

Build a private iPhone application called **HealthTrack** for one user's personal health and habit tracking.

The app should help answer three questions:

1. **Did I follow my healthy habits today?**
2. **Am I becoming more consistent over time?**
3. **Are my sleep, recovery, activity, and wellbeing trends improving?**

The application must track:

- Sleep
- Bedtime consistency
- Wake-time consistency
- Total sleep duration
- Deep sleep
- REM sleep
- Awake time
- HRV
- Resting heart rate
- Steps
- Workouts
- Exercise duration
- Meal timing
- Foods eaten
- Food quantity in grams
- Water intake
- Vitamins and supplements
- Mood
- Energy
- Stress

The app is for one person only.

Do not design a commercial SaaS product.

Prefer:
- local storage
- privacy
- low-friction logging
- clear trends
- reliability
- offline-first behavior

---

# 2. Critical Deployment Constraint

The development Mac may not be able to connect to the user's iPhone, so the project must not depend on it.

Therefore:

## Development Mac

Use this Mac for:

- project creation
- coding
- HealthKit integration
- SwiftData implementation
- UI development
- unit testing
- simulator testing
- visual QA
- mock health data
- Git version control

The entire project must be portable to another Mac.

## Personal Mac

The user will later copy the repository to a personal Mac.

The personal Mac will:

- open the Xcode project
- sign in with the user's Apple Account
- use Apple's free Personal Team provisioning
- connect to the user's iPhone
- install the app directly through Xcode
- refresh/reinstall the app approximately every 7 days as required by free provisioning

Do not require TestFlight or the paid Apple Developer Program for V1.

---

# 3. Project Location

First inspect the development environment.

Then create:

```text
~/Documents/HealthTrack
```

Everything related to this project must live inside that directory.

Create:

```text
HealthTrack/
├── HealthTrack.xcodeproj
├── HealthTrack/
├── HealthTrackTests/
├── HealthTrackUITests/
├── Documentation/
├── Scripts/
├── README.md
├── BUILD_STATUS.md
├── TRANSFER_TO_PERSONAL_MAC.md
├── DATA_SAFETY.md
├── ARCHITECTURE.md
├── TEST_PLAN.md
└── .gitignore
```

Initialize a Git repository.

Do not overwrite unrelated files.

---

# 4. Environment Inspection

Before writing application code, determine:

- macOS version
- Xcode version
- Swift version
- Command Line Tools status
- Git version
- available iOS Simulator runtimes
- available iPhone simulator device types
- whether Xcode signing teams are currently configured

Record findings in:

```text
BUILD_STATUS.md
```

Do not request:

- Apple password
- 2FA code
- private signing key
- recovery key

If authentication is required, instruct the user to perform it directly in Apple's UI.

---

# 5. Technology Stack

Use:

- Swift
- SwiftUI
- SwiftData
- HealthKit
- UserNotifications
- Swift Charts
- XCTest and/or Swift Testing
- Apple's native frameworks wherever possible

Avoid third-party dependencies unless absolutely necessary.

Do not add:

- Firebase
- analytics SDKs
- advertising SDKs
- remote tracking
- cloud databases
- external AI APIs

V1 must be local-first and privacy-first.

---

# 6. Architecture Principles

Use a layered architecture with clean separation of concerns.

Recommended structure:

```text
HealthTrack/
├── App/
│   ├── HealthTrackApp.swift
│   └── AppEnvironment.swift
│
├── Core/
│   ├── Models/
│   ├── Services/
│   ├── Repositories/
│   ├── Utilities/
│   └── Extensions/
│
├── Health/
│   ├── HealthKitManager.swift
│   ├── HealthDataRepository.swift
│   ├── SleepAggregator.swift
│   ├── ActivityAggregator.swift
│   └── MockHealthDataProvider.swift
│
├── Persistence/
│   ├── SwiftDataModels/
│   ├── PersistenceController.swift
│   ├── ExportService.swift
│   └── BackupService.swift
│
├── Features/
│   ├── Today/
│   ├── Log/
│   ├── Trends/
│   ├── WeeklyReview/
│   ├── Supplements/
│   ├── Meals/
│   ├── Water/
│   ├── Settings/
│   └── ReinstallStatus/
│
└── Shared/
    ├── Components/
    ├── DesignSystem/
    └── Charts/
```

Use protocols where appropriate so HealthKit and persistence logic can be mocked in tests.

Avoid putting application logic directly inside SwiftUI views.

---

# 7. Source of Truth Rules

## HealthKit is the source of truth for:

- sleep samples
- heart rate
- resting heart rate
- HRV
- steps
- workouts
- active energy
- walking/running distance
- exercise time
- weight if available
- oxygen saturation if available

Do not unnecessarily duplicate raw HealthKit samples into SwiftData.

Derived daily summaries may be cached if useful for performance.

## SwiftData is the source of truth for:

- meals
- food items
- grams consumed
- saved meals
- water logs
- supplements
- supplement schedules
- supplement adherence
- mood
- energy
- stress
- user goals
- application settings
- reinstall reminder metadata
- export metadata

---

# 8. HealthKit Integration

The user's Amazfit watch syncs into Zepp, and Zepp writes supported data into Apple Health.

Architecture:

```text
Amazfit
   ↓
Zepp
   ↓
Apple Health
   ↓
HealthKit
   ↓
HealthTrack
```

Do not integrate directly with Zepp in V1.

Request only supported HealthKit types.

Verify each identifier against the installed SDK before implementation.

Likely read permissions:

- HKCategoryTypeIdentifier.sleepAnalysis
- HKQuantityTypeIdentifier.heartRate
- HKQuantityTypeIdentifier.restingHeartRate
- HKQuantityTypeIdentifier.heartRateVariabilitySDNN
- HKQuantityTypeIdentifier.stepCount
- HKQuantityTypeIdentifier.activeEnergyBurned
- HKQuantityTypeIdentifier.appleExerciseTime where available
- HKQuantityTypeIdentifier.distanceWalkingRunning
- HKQuantityTypeIdentifier.bodyMass if useful
- HKQuantityTypeIdentifier.oxygenSaturation if available
- HKWorkoutType.workoutType()

Do not invent proprietary Zepp metrics.

Do not depend on Zepp Sleep Score or PAI.

---

# 9. Health Permission UX

On first launch:

1. Show a short onboarding explanation.
2. Explain why HealthTrack reads Apple Health.
3. Request only the required categories.
4. Handle partial or denied access gracefully.

Settings should display access status where Apple allows it.

Never falsely claim access was granted.

---

# 10. Sleep

Build a sleep aggregation layer.

For each night, calculate where data exists:

- sleep start
- final wake time
- total asleep time
- time in bed
- awake duration
- core/light sleep
- deep sleep
- REM sleep
- interruptions
- resting HR
- HRV

Important:

Do not assume "less REM is better."

Treat wearable sleep stages as estimates.

The app should focus on:

- sufficient sleep
- sleep regularity
- trends
- individual baseline changes

No diagnosis.

---

# 11. Meal Tracking

Create a `Meal` model.

Suggested fields:

```text
id
date
timestamp
mealType
notes
qualityRating
createdAt
updatedAt
```

Meal types:

- breakfast
- lunch
- dinner
- snack
- custom

Create `FoodEntry`.

Suggested fields:

```text
id
meal
foodName
grams
servingDescription
notes
createdAt
```

Support three logging modes.

## Quick

```text
Breakfast ✓
```

## Normal

```text
Breakfast
- oats
- banana
- yogurt
```

## Detailed

```text
Breakfast
- oats 80 g
- banana 120 g
- yogurt 180 g
```

All modes count as a logged meal.

Support:

- recent foods
- favorite foods
- saved meals
- duplicate previous meal
- "usual breakfast"
- edit meal
- delete meal

Do not require calorie or macro tracking in V1.

---

# 12. Meal Regularity

Settings should allow configurable meal windows.

Example defaults only:

```text
Breakfast: 07:30–09:30
Lunch:     12:00–14:00
Dinner:    19:00–21:00
```

Calculate:

- meal logged
- meal inside target window
- meal outside target window
- skipped meal
- late meal
- daily meal consistency
- weekly meal consistency

Do not hard-code meal times permanently.

---

# 13. Water Tracking

Create `WaterEntry`.

Fields:

```text
id
timestamp
amountML
createdAt
```

Quick actions:

- +250 ml
- +500 ml
- +750 ml
- custom amount

Settings:

```text
dailyWaterTargetML
```

Display:

```text
1.9 / 2.5 L
```

Calculate:

- daily total
- target reached
- weekly target adherence

---

# 14. Vitamins and Supplements

Supplements must be fully configurable.

Initial examples:

- Vitamin B
- Vitamin C
- Vitamin D
- Iron
- Magnesium

Do not hard-code these into business logic.

Create `Supplement`.

Suggested fields:

```text
id
name
dosageText
active
notes
createdAt
updatedAt
```

Create `SupplementSchedule`.

Suggested fields:

```text
id
supplement
daysOfWeek
preferredTime
reminderEnabled
reminderTime
startDate
endDate
```

Create `SupplementLog`.

Suggested fields:

```text
id
supplement
scheduledDate
scheduledTime
status
takenAt
createdAt
```

Statuses:

- pending
- taken
- skipped
- missed

Support:

- every day
- selected weekdays
- morning/afternoon/evening
- custom reminder time
- inactive/paused supplement

Calculate:

- daily adherence
- weekly adherence
- monthly adherence
- streak
- most frequently missed supplement

Do not recommend starting/stopping supplements or changing dosage.

---

# 15. Activity and Exercise

Read HealthKit workouts and steps.

Show:

- steps today
- workouts today
- workout type
- workout duration
- weekly workout count
- total workout time
- optional active energy

Settings should allow:

- step target
- workouts per week target

Avoid treating calorie estimates as exact.

---

# 16. Daily Check-In

Once per day, optionally record:

```text
Energy 1–5
Mood   1–5
Stress 1–5
Notes
```

Create `DailyCheckIn`.

The interaction should take under 10 seconds.

---

# 17. Today Screen

Primary question:

> Am I having a healthy day?

Show cards for:

## Sleep

- total sleep
- bedtime status
- deep sleep
- REM
- HRV
- resting HR

## Meals

- breakfast status
- lunch status
- dinner status
- meal consistency

## Water

- current amount / target

## Supplements

- today's scheduled supplements
- taken/pending/missed

## Activity

- steps
- workouts

## Check-In

- energy
- mood
- stress

## Daily Consistency

Show a behavior consistency percentage.

Do not call it a medical "health score."

---

# 18. Behavior Score

Separate behavior from physiology.

## Behavior / Consistency

Initial default weights:

```text
Sleep routine     25%
Meal routine      20%
Exercise          20%
Hydration         15%
Supplements       10%
Daily movement    10%
```

The score should reflect:

> Did I do what I intended to do?

Do not punish the user for a low HRV reading.

Document scoring formulas.

Make the architecture capable of supporting configurable weights later.

---

# 19. Health Signals

Display separately:

- total sleep
- deep sleep
- REM
- HRV
- resting heart rate
- energy
- workout recovery trends

Use personal baselines and trends.

Do not present medical diagnosis.

---

# 20. Trends

Support:

- 7 days
- 30 days
- 90 days

Charts where useful:

- sleep duration
- bedtime consistency
- wake-time consistency
- HRV
- resting HR
- deep sleep
- REM
- steps
- workout frequency
- water adherence
- meal timing adherence
- supplement adherence
- energy

Use Swift Charts.

Do not create charts that do not help the user make decisions.

---

# 21. Weekly Review

Generate a human-readable weekly review.

Example:

```text
WEEK OF OCT 26

Consistency
84%

Sleep
Average              7h 18m
Bedtime target       5/7
Wake target          6/7
HRV trend            ↑
Resting HR           Stable

Food
Meals on time        86%
Late dinners         2
Meals logged         19/21

Exercise
Workouts             4 / 4
Steps                8,420 avg

Water
Target achieved      5 / 7

Supplements
Adherence            93%

Energy
Average              4.1 / 5

Best habit
Regular bedtime

Needs attention
Water
Dinner timing
```

Make the review useful, concise, and behavior-oriented.

---

# 22. Insights

Only generate descriptive observations when sample size is sufficient.

Examples:

- "Your average sleep duration was 24 minutes longer on nights when dinner was before 8:30 PM."
- "Your 30-day HRV average is 6% above the prior 30 days."
- "You met your bedtime target on 78% of nights this month."
- "Magnesium was logged on 26 of 30 scheduled days."

Rules:

- call these associations, patterns, or observations
- never claim causality
- never diagnose
- use minimum sample thresholds
- document methodology

---

# 23. Notifications

Use local notifications.

Allow reminders for:

- supplements
- meals
- water
- bedtime
- daily check-in

Notifications must be user-configurable.

Do not spam.

---

# 24. Reinstall / Free Provisioning Support

This is a critical V1 requirement.

The app will be installed using Apple's free Personal Team provisioning.

The app may stop launching after approximately 7 days unless re-signed/reinstalled from Xcode.

The app MUST help the user remember this.

## Reinstall Status Feature

Create a `ReinstallStatus` feature.

At first successful physical-device launch, store:

```text
installationDate
lastProvisioningRefreshDate
nextSuggestedRefreshDate
```

Default:

```text
nextSuggestedRefreshDate = lastProvisioningRefreshDate + 6 days
```

Use 6 days rather than waiting until the 7-day limit.

## Today Screen Indicator

When within 2 days of the suggested refresh date, show:

```text
App refresh due soon
Reconnect to your personal Mac and run HealthTrack from Xcode before <date>.
```

When due:

```text
App refresh recommended today
Connect your iPhone to your personal Mac and press Run in Xcode.
```

Do not suggest deleting the app.

## Settings Section

Add:

```text
Settings
→ App Installation
```

Show:

- last refresh date
- suggested next refresh date
- "How to refresh HealthTrack"
- "Backup before reinstall"
- export data button

Include step-by-step instructions:

```text
1. Connect iPhone to personal Mac.
2. Open HealthTrack.xcodeproj in Xcode.
3. Select your iPhone.
4. Make sure your Personal Team is selected.
5. Press Run.
6. Do NOT delete the existing HealthTrack app first.
7. Confirm the app opens.
```

## Notification

Optionally schedule a local notification on Day 6:

```text
HealthTrack app refresh due tomorrow.
Connect your iPhone to your personal Mac and run the project from Xcode.
```

Allow this reminder to be disabled.

---

# 25. Data Preservation Is Critical

Manual health logs must not be casually lost.

The app must assume that reinstalling incorrectly could destroy local data.

## Rule

Never instruct the user to uninstall or delete the existing app as part of normal provisioning refresh.

Normal process:

```text
existing app
→ Xcode build/run over existing bundle identifier
→ updated/re-signed app
```

Use the SAME bundle identifier every time.

Changing the bundle identifier creates a different app/container and must be avoided.

## Backup

Implement data export early.

At minimum support:

- JSON export
- CSV export

Export:

- meals
- food entries
- water
- supplements
- supplement schedules
- supplement logs
- daily check-ins
- user goals
- settings where sensible

HealthKit data does not need to be copied because Apple Health remains its source.

## Backup UI

Settings:

```text
Data & Backup
├── Export all data
├── Export CSV
├── Export JSON
├── Last export date
└── Backup reminder
```

Before a scheduled provisioning refresh, display:

```text
Your HealthTrack data should remain intact when you refresh the app through Xcode without deleting it.

For extra safety, export a backup first.
```

## Data Integrity

Create automated tests proving:

- migrations do not erase existing SwiftData content
- application upgrades preserve records
- model schema changes are handled intentionally
- exports can be decoded/re-imported where practical

---

# 26. Data Safety Document

Create:

```text
DATA_SAFETY.md
```

It must explain:

1. what lives in HealthKit
2. what lives in SwiftData
3. what happens during normal Xcode reinstall/refresh
4. why the bundle identifier must remain unchanged
5. why the user must not delete the app
6. how to export a backup
7. how to restore data if import is implemented
8. what could cause data loss
9. safe upgrade procedure

---

# 27. Offline First

Everything should work without internet.

Manual logging must not depend on network access.

HealthKit queries are local.

---

# 28. App Navigation

Use a native tab-based interface.

Primary tabs:

```text
Today
Log
Trends
Weekly
Settings
```

Do not create excessive navigation complexity.

---

# 29. Logging UX

The manual logging burden must stay extremely low.

Target:

```text
< 30 seconds/day
```

Examples:

## Water

One tap.

## Supplements

One tap per item or "Mark all taken."

## Meal

Quick log in one tap or detailed entry when desired.

## Check-In

Three taps.

Prioritize consistency over perfect detail.

---

# 30. Error Handling

Handle:

- HealthKit unavailable
- permissions denied
- partial permissions
- no sleep data
- no HRV data
- no workout history
- malformed manual entry
- zero grams
- duplicate water taps
- time-zone changes
- daylight-saving changes
- app upgraded with existing data

Never crash because a HealthKit metric is absent.

---

# 31. Testing Strategy

Do not declare a milestone complete just because the app compiles.

Create unit tests for:

- meal-window classification
- meal consistency
- supplement scheduling
- supplement adherence
- water totals
- behavior score
- weekly aggregation
- trend comparison
- sleep-day assignment
- timezone handling
- daylight-saving boundaries
- reinstall reminder calculations
- export serialization
- data migrations
- missing-data behavior

Create mock HealthKit providers.

Test states:

- no data
- one day
- seven days
- 30 days
- 90 days
- partial HealthKit permissions
- denied HealthKit permissions
- missing sleep stage data
- multiple workouts
- missed vitamins
- skipped meals
- large number of food items
- long supplement names

---

# 32. Simulator QA

Use mock data because real HealthKit device data is not available in the simulator.

Test:

- smallest supported iPhone
- large iPhone
- portrait
- Dark Mode
- Light Mode
- Dynamic Type
- empty states
- long text
- lots of meal entries
- many supplements
- 90-day trends

Inspect visually.

Fix clipping and layout problems.

---

# 33. Git Workflow

Use meaningful commits.

Suggested milestone commits:

```text
chore: initialize HealthTrack project
feat: add SwiftData persistence layer
feat: add HealthKit abstraction
feat: add sleep aggregation
feat: add meal logging
feat: add hydration tracking
feat: add supplement scheduling
feat: add activity tracking
feat: add Today dashboard
feat: add behavior scoring
feat: add trend charts
feat: add weekly review
feat: add reinstall reminders
feat: add export and backup
test: complete core test coverage
docs: add personal Mac deployment guide
```

Do not commit broken builds unless specifically documenting a temporary state.

---

# 34. BUILD_STATUS.md

Maintain continuously.

Suggested format:

```text
# Build Status

## Current Milestone
M3 — HealthKit Integration

## Build
PASS / FAIL

## Tests
42 passed
0 failed

## Simulator QA
Pending / Complete

## Features
[x] Project setup
[x] Persistence
[ ] HealthKit
[ ] Sleep
...

## Known Issues
...

## Next Action
...
```

Update after every milestone.

---

# 35. Milestone Plan

Follow these milestones in order.

Do not skip ahead without reason.

---

## M0 — Environment and Repository

Deliverables:

- project directory
- Git repository
- environment inspection
- README
- BUILD_STATUS
- ARCHITECTURE skeleton
- TEST_PLAN skeleton

Gate:

```text
Repository exists
Xcode toolchain verified
Project path correct
Git clean
```

---

## M1 — Xcode App Skeleton

Deliverables:

- Xcode project
- SwiftUI app launches in simulator
- tab navigation
- placeholder Today/Log/Trends/Weekly/Settings screens

Gate:

```text
xcodebuild succeeds
simulator launch succeeds
```

---

## M2 — Persistence Layer

Deliverables:

- SwiftData container
- all manual-tracking models
- repository interfaces
- sample data

Gate:

```text
create/read/update/delete tests pass
restart simulator preserves data
```

---

## M3 — HealthKit Abstraction

Deliverables:

- HealthKitManager
- permissions
- protocol abstraction
- mock provider
- query service

Gate:

```text
real HealthKit code compiles
mock HealthKit tests pass
denied/partial access handled
```

---

## M4 — Sleep and Recovery

Deliverables:

- sleep aggregation
- HRV
- resting HR
- sleep summary
- mock nightly data

Gate:

```text
sleep tests pass
no double counting
cross-midnight logic verified
```

---

## M5 — Meals and Food

Deliverables:

- meal CRUD
- food grams
- quick/normal/detailed logging
- recent foods
- saved meals
- meal targets

Gate:

```text
meal-window tests pass
logging UX tested
```

---

## M6 — Water

Deliverables:

- quick-add buttons
- custom amount
- daily totals
- target adherence

Gate:

```text
water tests pass
rapid duplicate tap handling checked
```

---

## M7 — Supplements

Deliverables:

- supplement CRUD
- recurring schedules
- taken/skipped/missed
- reminders
- adherence metrics

Gate:

```text
weekday schedule tests pass
timezone tests pass
adherence calculations pass
```

---

## M8 — Activity

Deliverables:

- steps
- workouts
- workout duration
- weekly targets

Gate:

```text
mock workouts render correctly
missing HealthKit data handled
```

---

## M9 — Today Dashboard

Deliverables:

- polished Today screen
- sleep
- meals
- water
- supplements
- activity
- check-in
- consistency score

Gate:

```text
all cards render
empty states work
no clipped UI
```

---

## M10 — Behavior Score

Deliverables:

- scoring service
- documented weights
- daily score
- weekly averages

Gate:

```text
all scoring unit tests pass
missing components handled predictably
```

---

## M11 — Trends

Deliverables:

- 7/30/90-day charts
- baseline calculations
- HealthKit + manual data trends

Gate:

```text
no-data and sparse-data cases work
charts visually inspected
```

---

## M12 — Weekly Review

Deliverables:

- weekly aggregation
- concise narrative summary
- best habit
- attention area

Gate:

```text
week boundary tests pass
review works with partial data
```

---

## M13 — Insights

Deliverables:

- descriptive association engine
- minimum sample thresholds
- safe wording

Gate:

```text
no causal language
sample thresholds tested
```

---

## M14 — Reinstall Reminder

Deliverables:

- installation metadata
- 6-day suggested refresh
- Today warning
- Settings instructions
- optional Day-6 notification

Gate:

```text
date calculations tested
warning states verified
```

---

## M15 — Export and Backup

Deliverables:

- JSON export
- CSV export
- share sheet
- last export date
- documentation

Gate:

```text
exports parse successfully
all manual data represented
```

---

## M16 — Full QA

Deliverables:

- all tests run
- simulator QA
- Dark Mode
- Dynamic Type
- empty states
- 30/90-day data sets

Gate:

```text
0 known crashing bugs
0 failing tests
clean build
```

---

## M17 — Transfer Package

Deliverables:

- TRANSFER_TO_PERSONAL_MAC.md
- DATA_SAFETY.md
- README finalized
- clean Git repository

Gate:

```text
project contains no machine-specific paths
fresh clone builds on development Mac
```

---

## M18 — Personal Mac Installation

This milestone happens later on the user's personal Mac.

Steps:

1. Copy or clone repository.
2. Install/open Xcode.
3. Sign in to Apple Account in Xcode.
4. Choose Personal Team.
5. Confirm stable bundle identifier.
6. Connect iPhone.
7. Trust device.
8. Enable Developer Mode if required.
9. Select iPhone as destination.
10. Press Run.
11. Grant HealthKit access.
12. Grant notification access.
13. Verify real HealthKit data.

Do not delete the app during normal refreshes.

---

## M19 — Real Data Validation

Compare HealthTrack against Apple Health for:

- total sleep
- deep sleep
- REM
- HRV
- resting HR
- steps
- latest workout

If values differ:

- inspect raw HealthKit samples
- inspect source devices
- inspect time boundaries
- inspect deduplication
- fix aggregation logic

Do not arbitrarily modify numbers to make them match.

---

# 36. Personal Mac Refresh Procedure

Create a permanent document:

```text
Documentation/FREE_PROVISIONING_REFRESH.md
```

Contents should include:

```text
Every ~6 days:

1. Export HealthTrack backup.
2. Connect your iPhone to your personal Mac.
3. Open HealthTrack.xcodeproj.
4. Select the same Personal Team.
5. Confirm the bundle identifier has NOT changed.
6. Select your existing iPhone.
7. Press Run.
8. Let Xcode reinstall/re-sign over the existing app.
9. Do NOT delete HealthTrack first.
10. Open HealthTrack and confirm your data is present.
11. Confirm Health permissions still work.
12. HealthTrack resets the next suggested refresh date.
```

The in-app reminder must reference this process in plain language.

---

# 37. Upgrade Safety

Before changing SwiftData models after V1:

1. inspect migration impact
2. create migration plan
3. test with populated database
4. verify no records disappear
5. only then merge the schema change

Never casually rename/remove persisted fields.

---

# 38. Privacy

V1 must not transmit health or habit data off-device.

No network endpoint is needed.

No telemetry.

No AI API.

No tracking.

Document this in Settings → Privacy.

---

# 39. Completion Definition

The project is not complete until:

- clean Xcode build
- unit tests pass
- simulator QA complete
- all five tabs functional
- HealthKit integration implemented
- manual logging complete
- weekly review complete
- reinstall reminder complete
- data export complete
- transfer documentation complete
- project builds from a fresh checkout

---

# 40. How to Work With the Product Owner

Do the engineering work yourself.

Do not repeatedly ask:

> Would you like me to continue?

Continue automatically.

Only stop if:

- Apple authentication is required
- 2FA is required
- admin permission is required
- destructive action requires confirmation
- an unavoidable product decision cannot reasonably be inferred

When blocked, report:

```text
BLOCKED ON:
<one concise issue>

WHAT YOU NEED TO DO:
1.
2.
3.

DO NOT SHARE:
passwords / 2FA codes / secrets

WHEN COMPLETE:
Tell me "<specific confirmation>"
```

Then resume from the same milestone.

---

# 41. First Action

Start with M0.

Do not begin feature implementation yet.

Perform these actions now:

1. inspect the development environment
2. create `~/Documents/HealthTrack`
3. initialize Git
4. create required documentation files
5. create/update BUILD_STATUS.md
6. verify Xcode tooling
7. proceed to M1 if no blocker exists

Keep working milestone by milestone until blocked by a genuine human-only requirement.
