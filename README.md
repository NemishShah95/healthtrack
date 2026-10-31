# HealthTrack

A private, single-user iPhone app for daily health and habit tracking. It answers three questions:

1. Did I follow my healthy habits today?
2. Am I becoming more consistent over time?
3. Are my sleep, recovery, activity and wellbeing trends improving?

Sleep, HRV, resting heart rate, steps and workouts are read from Apple Health (Amazfit → Zepp → Apple Health → HealthTrack).
Meals, water, protein, supplements, a gym journal and a daily check-in are logged in the app and stored only on the phone.
No accounts, no cloud, no analytics, no third-party code.

## Status: in daily use (local production)

_As of 2026-11-01. Live details: [BUILD_STATUS.md](BUILD_STATUS.md)._

| | |
| --- | --- |
| Installed on | iPhone 16 Pro, since 2026-11-01. Works on any iPhone with iOS 17+ (16 Pro, 17, 17 Pro…) |
| Version | 1.0 (1) |
| Signing | Free Apple Personal Team. **Must be refreshed from Xcode every ~6 days** (see the routine below) |
| Tests | 72 pass in the iOS 27.2 simulator (66 logic/database + 6 UI, including Apple's accessibility audit) |
| Database | `SchemaV1` is **frozen** now that it holds real data; a test fails on any in-place change |
| Spec milestones | M0–M18 done. **M19 (compare numbers with the Apple Health app) is still open** |

### Ready to use
- **Today**: a consistency ring and tiles with one tap each. Water `+250`, meals `+ Dinner`, protein `+20 g`, supplements `All ✓`, gym `+ Log`, check-in in three taps. Swipe back through the **last 5 days** to fill in anything missed.
- **Sleep and recovery**: last night's sleep, bed/wake times against your targets, deep, REM, awake time and interruptions; HRV and resting heart rate against your own 30-day average.
- **Meals**: quick log, or foods with optional grams (`oats 80 g`); recent and favourite foods; a saved "usual breakfast"; repeat, edit and history.
- **Gym journal**: body-part focus plus exercises typed one per line (`Squat 5x5 100 kg`, `Treadmill 20 min 3 km`), repeat last session, history and a body-part focus chart. A session also recorded by the watch counts as one workout, not two.
- **Protein, water and supplements**: daily targets, weekday schedules, taken/skipped/missed, adherence and streaks.
- **Trends**: 7/30/90-day charts for sleep, bed/wake consistency, HRV, resting HR, deep/REM, steps, workouts, water, protein, meals on time, supplements and energy.
- **Weekly review**: score, best habit, what to watch, key numbers, and observations (patterns, never causes or advice).
- **Safety**: JSON/CSV export and restore, a Mac-side backup script, a refresh-due banner and notification, opt-in reminders.

### Not done yet / known limits
- **M19 open**: HealthTrack's numbers still need a side-by-side check against the Apple Health app with real data.
- **Health data isn't live**: it's read when the app opens or you pull down to refresh. Zepp can be slow to write to Apple Health; open Zepp first if last night is missing.
- **Expires every 7 days** with free signing. Data survives as long as the app isn't deleted.
- **One phone only**: no iCloud sync between devices, by design.
- Protein and gym notes aren't part of the consistency score (the spec's weights are kept).
- With 8 tiles, Today scrolls slightly on a 6.3" iPhone.
- Meal reminders fire at a fixed time even if the meal is already logged. Each supplement has one schedule (take it twice a day = add it twice).

## Owner's routine

| When | What |
| --- | --- |
| Daily | Tap tiles on Today. Under 30 seconds |
| Every ~6 days | Refresh: connect the iPhone, open `HealthTrack.xcodeproj`, press **Run**, with the **same Apple Account** every time. Never delete the app. Steps: [FREE_PROVISIONING_REFRESH.md](Documentation/FREE_PROVISIONING_REFRESH.md) |
| Each refresh | Back up: Settings → Data & Backup → **Export JSON**, and/or `Scripts/backup-from-iphone.sh` on the Mac |

## Key facts that must not change

| Item | Value |
| --- | --- |
| Bundle identifier | `com.nemishshah.healthtrack`. **Never change it.** A new identifier means a new, empty app |
| Apple Account | The same personal account on every Mac that installs or refreshes the app |
| Minimum iOS | 17.0 |
| Database schema | `SchemaV1` frozen; changes only via `SchemaV2` + a tested migration ([DATA_SAFETY.md](DATA_SAFETY.md)) |

## For developers

### Repository layout

```text
.
├── HealthTrack.xcodeproj      Open this in Xcode
├── HealthTrack/               App source
│   ├── App/                   Entry point, onboarding, reminders
│   ├── Core/                  Pure logic: scoring, sleep, meals, gym parsing, supplements, export format
│   ├── Health/                Apple Health reading, plus a mock for the simulator
│   ├── Persistence/           SwiftData database (SchemaV1), backup/restore, sample data
│   ├── Features/              Today (+ detail pages) · Meals · Gym · Supplements · Trends · Weekly · Settings
│   └── Shared/                Reusable views, accessible colour palette
├── HealthTrackTests/          Unit tests (Swift Testing)
├── HealthTrackUITests/        UI, accessibility-audit and screenshot tests
├── Scripts/                   backup-from-iphone.sh
├── Documentation/             Original build spec and the refresh procedure
├── Package.swift              Lets `swift test` run logic and database tests without a simulator
└── *.md                       Status, architecture, test plan, data safety, install guide
```

### Running the tests

```sh
# Logic, database and mock Health data, in about a second (no simulator):
swift test

# Everything, including UI tests, in the simulator:
xcodebuild test -project HealthTrack.xcodeproj -scheme HealthTrack \
  -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO
```

These need Xcode selected (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`). Xcode 27's simulator window is the **DeviceHub** app.

Screenshots of every screen: put `TEST_RUNNER_SCREENSHOTS=1` (or `=empty` for a brand-new install) in front of the `xcodebuild test` command; see `HealthTrackUITests/ScreenshotTour.swift`.

### Simulator launch arguments

Set these in Xcode → Product → Scheme → Edit Scheme → Run → Arguments. The iPhone build never uses them.

| Argument | Effect |
| --- | --- |
| `-seedSampleData` | Fills an empty database with 90 days of realistic logs, including gym and protein |
| `-mockHealth full` / `empty` / `denied` / `partial` / `noStages` / `unavailable` | Picks the fake Apple Health scenario (the simulator defaults to `full`) |
| `-inMemoryStore` | Uses a throwaway database |
| `-skipOnboarding` | Skips the first-launch screen |
| `-refreshDaysAgo 5` | Pretends the last Xcode refresh was 5 days ago, to see the refresh warning |

## Documents

- [BUILD_STATUS.md](BUILD_STATUS.md): live status, environment, decisions, next action
- [ARCHITECTURE.md](ARCHITECTURE.md): how the app is built, plus the score, sleep and insight formulas
- [DATA_SAFETY.md](DATA_SAFETY.md): where data lives and how not to lose it; read before reinstalling or upgrading
- [TRANSFER_TO_PERSONAL_MAC.md](TRANSFER_TO_PERSONAL_MAC.md): installing on an iPhone (any Mac, same Apple Account), including for other people
- [Documentation/FREE_PROVISIONING_REFRESH.md](Documentation/FREE_PROVISIONING_REFRESH.md): the refresh you repeat about every 6 days
- [TEST_PLAN.md](TEST_PLAN.md): what is tested and how
- [Documentation/HealthTrack_Codex_Master_Build_Spec.md](Documentation/HealthTrack_Codex_Master_Build_Spec.md): the original specification
