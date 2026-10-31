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
├── HealthTrack/               App source
│   └── Core/                  Pure logic (Foundation only): scoring, sleep, meals, supplements, export
├── HealthTrackTests/          Unit tests (Swift Testing)
│   └── Core/                  Core logic tests: run with `swift test`
├── Documentation/             Original build spec and the refresh procedure
├── Package.swift              Lets `swift test` run the Core tests without Xcode
├── ARCHITECTURE.md            Layers, data ownership, scoring formulas, methodology
├── TEST_PLAN.md               What is tested and how
├── DATA_SAFETY.md             Where data lives and how not to lose it
└── TRANSFER_TO_PERSONAL_MAC.md  Installing on your iPhone from your personal Mac
```

The Xcode project (`HealthTrack.xcodeproj`), UI, HealthKit and SwiftData layers are added from milestone M1 onward.

## Running the tests

Core logic, with no Xcode needed (Command Line Tools are enough):

```sh
swift test
```

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
