# HealthTrack

A private, single-user iPhone app for daily health and habit tracking. It answers three questions:

1. Did I follow my healthy habits today?
2. Am I becoming more consistent over time?
3. Are my sleep, recovery, activity and wellbeing trends improving?

Sleep, heart rate, HRV, steps and workouts are read from Apple Health (Amazfit → Zepp → Apple Health → HealthTrack).
Meals, water, supplements and the daily check-in are logged in the app and stored on the phone with SwiftData.
Nothing leaves the device: no accounts, no network calls, no analytics, no third-party dependencies.

**Status:** see [BUILD_STATUS.md](BUILD_STATUS.md).

## Repository layout

```text
.
├── HealthTrack.xcodeproj      Open this in Xcode
├── HealthTrack/               App source
│   ├── App/                   Entry point, onboarding, reminders
│   ├── Core/                  Pure logic: scoring, sleep, meals, supplements, export format
│   ├── Health/                Apple Health reading, plus a mock for the simulator
│   ├── Persistence/           SwiftData database, backup/restore, sample data
│   ├── Features/              Today · Log · Trends · Weekly · Settings screens
│   └── Shared/                Reusable views
├── HealthTrackTests/          Unit tests (Swift Testing)
├── HealthTrackUITests/        Launch/UI tests
├── Documentation/             Original build spec and the refresh procedure
├── Package.swift              Lets `swift test` run logic and database tests without a simulator
├── ARCHITECTURE.md            Layers, data ownership, scoring formulas, methodology
├── TEST_PLAN.md               What is tested and how
├── DATA_SAFETY.md             Where data lives and how not to lose it
└── TRANSFER_TO_PERSONAL_MAC.md  Installing on your iPhone from your personal Mac
```

## Running the tests

```sh
# Logic, database and mock Health data, in about a second (no simulator):
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# Everything, including UI tests, in the simulator:
xcodebuild test -project HealthTrack.xcodeproj -scheme HealthTrack -destination 'platform=iOS Simulator,name=iPhone 17'
```

If you ran `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, the `DEVELOPER_DIR=` part isn't needed.

## Simulator launch arguments

Set these in Xcode → Product → Scheme → Edit Scheme → Run → Arguments. They only matter in development; the iPhone build never uses them.

| Argument | Effect |
| --- | --- |
| `-seedSampleData` | Fills an empty database with 90 days of realistic meals, water, supplements and check-ins |
| `-mockHealth full` / `empty` / `denied` / `partial` / `noStages` / `unavailable` | Picks the fake Apple Health scenario (the simulator defaults to `full`) |
| `-inMemoryStore` | Uses a throwaway database |
| `-skipOnboarding` | Skips the first-launch screen |
| `-refreshDaysAgo 5` | Pretends the last Xcode refresh was 5 days ago, to see the refresh warning |

## Key facts that must not change

| Item | Value |
| --- | --- |
| Bundle identifier | `com.nemishshah.healthtrack`. **Never change it.** A new identifier means a new, empty app. |
| Minimum iOS | 17.0 |
| Signing | Free Apple "Personal Team", on your personal Mac only |

## Documents

- [ARCHITECTURE.md](ARCHITECTURE.md): how the app is built, plus the behaviour-score and insight formulas
- [DATA_SAFETY.md](DATA_SAFETY.md): read before reinstalling or upgrading
- [TRANSFER_TO_PERSONAL_MAC.md](TRANSFER_TO_PERSONAL_MAC.md): first install on your iPhone
- [Documentation/FREE_PROVISIONING_REFRESH.md](Documentation/FREE_PROVISIONING_REFRESH.md): the refresh you repeat about every 6 days
- [Documentation/HealthTrack_Codex_Master_Build_Spec.md](Documentation/HealthTrack_Codex_Master_Build_Spec.md): the original specification
