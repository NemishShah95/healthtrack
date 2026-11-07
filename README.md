# HealthTrack

A private, single-user iPhone app for daily health and habit tracking. It answers three questions:

1. Did I follow my healthy habits today?
2. Am I becoming more consistent over time?
3. Are my sleep, recovery, activity and wellbeing trends improving?

Sleep, HRV, resting heart rate, steps and workouts are read from Apple Health (Amazfit → Zepp → Apple Health → HealthTrack).
Meals, water, protein, vitamins, a gym journal, training goals and a daily check-in are logged in the app and stored only on the phone.
No accounts, no cloud, no analytics, no third-party code.

## Status: in daily use (local production)

_As of 2026-11-07. Live details: [BUILD_STATUS.md](BUILD_STATUS.md)._

| | |
| --- | --- |
| Installed on | iPhone 16 Pro, since 2026-11-01. Works on any iPhone with iOS 17+ (16 Pro, 17, 17 Pro…) |
| Version | 1.0 (1) |
| Signing | Free Apple Personal Team. **Must be refreshed from Xcode every ~6 days** (see the routine below) |
| Tests | 81 logic/database tests (`swift test`, also on GitHub after every push) + 8 UI tests in the iOS 27.2 simulator, including Apple's accessibility audit |
| Database | `SchemaV1` is **frozen**; a test fails on any in-place change. Training goals live inside the goals settings, so they needed no change |
| Spec milestones | M0–M18 done. **M19 (compare numbers with the Apple Health app) is still open** |

### Ready to use
- **Today**: the week strip (one bar per day, lime when the day went well), a bento of Sleep (with a stage chart), Steps and your consistency ring, then one-tap tiles: water `+250`, meals `+ Lunch`, protein `+20 g`, vitamins `All ✓` / `+ Log`, Recovery (HRV against your usual range) and check-in. A Workouts list shows the gym journal and watch workouts. Swipe back through the **last 7 days** to fill in anything missed.
- **Training**: goals such as "Run 5 km, 3× a week", "Bench press 4×8 at 60 kg" or a one-off milestone ("first 10 km run"). Each goal shows this week's progress, the last 8 weeks and your streak, or your best attempt for milestones. Goals tick off from what you log in the gym journal; `+ Log` opens it with the exercise ready.
- **Gym journal**: body parts and exercises picked from dropdowns, then sets, reps, weight, time or distance from dropdowns. Repeat last session, history, body-part focus chart. A session the watch also recorded counts once.
- **Sleep and recovery**: last night's sleep and stages, bed and wake times against your targets; HRV and resting heart rate against **your usual range** (middle of the previous 30 days ± a typical swing, shown after 7 days of data).
- **Meals, vitamins, protein, water**: foods, vitamins, doses and amounts all come from dropdowns (favourites and recent first, "Other…" for anything new). Scheduled vitamins plus a vitamin journal for extras and as-needed ones.
- **Siri and Shortcuts**: "Log water in HealthTrack", "Log 500 ml of water in HealthTrack", "Log Vitamin D in HealthTrack", "Log 20 grams of protein in HealthTrack", "Log lunch in HealthTrack". Also in Spotlight, the Shortcuts app and the Action button.
- **Watch sync check**: the pill at the top of Today turns amber when nothing has arrived from the watch for yesterday or today, and says what to do.
- **Trends**: 7/30/90-day charts. HRV and resting heart rate show your usual range as a band.
- **Weekly review**: score, best habit, what to watch, key numbers, observations, and **one small experiment to try next week** aimed at your weakest habit.
- **Safety**: JSON/CSV export and restore, a Mac-side backup script that now checks each copy opens, a refresh-due banner and notification, opt-in reminders.

### Not done yet / known limits
- **M19 open**: HealthTrack's numbers still need a side-by-side check against the Apple Health app with real data.
- **Health data isn't live**: it's read when the app opens or you pull down to refresh. Zepp can be slow to write to Apple Health; open Zepp first if last night is missing.
- **Expires every 7 days** with free signing. Data survives as long as the app isn't deleted.
- **One phone only**: no iCloud sync between devices, by design.
- Training goals count gym-journal entries only. Runs recorded by the watch don't tick off distance goals yet (that needs reading workout distance from Apple Health).
- Notes stay free text, and "Other…" lets you type a name that isn't in a list; everything else is a dropdown or a one-tap button.
- Protein, gym notes, training goals and journaled vitamins aren't part of the consistency score (the spec's weights are kept).
- Meal reminders fire at a fixed time even if the meal is already logged. Each vitamin has one schedule (take it twice a day = add it twice).

## Owner's routine

| When | What |
| --- | --- |
| Daily | Tap tiles on Today, or tell Siri. Under 30 seconds |
| Every ~6 days | Refresh: connect the iPhone, open `HealthTrack.xcodeproj`, press **Run**, with the **same Apple Account** every time. Never delete the app. Steps: [FREE_PROVISIONING_REFRESH.md](Documentation/FREE_PROVISIONING_REFRESH.md) |
| Each refresh | Back up: Settings → Data & Backup → **Export JSON**, and/or `Scripts/backup-from-iphone.sh` on the Mac |

## Key facts that must not change

| Item | Value |
| --- | --- |
| Bundle identifier | `com.nemishshah.healthtrack`. **Never change it.** A new identifier means a new, empty app |
| Apple Account | The same personal account on every Mac that installs or refreshes the app |
| Minimum iOS | 17.0 |
| Database schema | `SchemaV1` frozen; changes only via `SchemaV2` + a tested migration ([DATA_SAFETY.md](DATA_SAFETY.md)) |

## Design

Designed by **Nemish Shah**. The direction: calm, minimal and dark, with one number per card and nothing you don't need. Tokens live in [`HealthTrack/Shared/Theme.swift`](HealthTrack/Shared/Theme.swift).

### Colour

The app is dark-only. Surfaces are opaque so contrast can be measured. Body text is at least 9:1 on cards; secondary text is at least 6.8:1, even on the brightest glow.

| Token | Hex | Used for |
| --- | --- | --- |
| Background | `#0B1E2B` → `#050C11` | Vertical gradient behind every screen |
| Glow, teal | `#1D5E5C` at 40% | Soft radial light, top right |
| Glow, lime | `#3F6220` at 24% | Soft radial light, lower left |
| Card | `#0E1C23` | Every card, 26 pt corners, 1 pt white 7% outline |
| Row | `#10222A` | List and form rows |
| Text | `#F1F5F4` | Numbers and labels |
| Secondary | `#AEC0C4` | Captions, units, details |
| Lime | `#C8F25C` (deep `#86D65A`) | Progress, rings, actions, the week strip |
| Teal | `#4FC9BD` | Sleep and recovery icons, check-in |
| Sleep stages | Awake `#E6F6F3` · REM `#86E6DA` · Core `#3DB3A9` · Deep `#1F7C78` | Stage chart only |
| Categories | Water `#62D2F5` · Protein `#FF9DB5` · Vitamins `#BCA8FF` · Meals/warning `#FFC266` · Alert `#FF7A7A` | Icons and progress bars |

### Type

SF Pro throughout, scaled with Dynamic Type.

- **Numbers**: light weight at 30–40 pt, with units at 45% size in regular weight (`7h 16m`, `12,335 steps`).
- **Screen titles**: light-weight large titles.
- **Card labels**: subheadline in secondary colour.
- **Details**: caption.

### Components

- **Card**: dark, 26 pt corners. The whole card is one button that opens its page.
- **Pill**: lime capsule with black semibold text and a 44 pt tap target. A card carries at most one.
- **Ring**: a lime angular-gradient arc on a white 10% track, with a light percentage in the middle.
- **Week strip**: S–S with an 18 × 4 pt bar above each day. Lime means consistency of at least 70%, dim lime means the day was started, grey means no data. The selected day is circled.
- **Sleep stage chart**: awake at the top, deep at the bottom, one rounded block per stage.
- **Steps orbit**: a quarter circle in the card's corner, with a glowing dot that travels as you near your target.
- **Workout row**: a 44 pt circular icon in lime, title, `time · detail`, and minutes on the right.
- **Sync pill**: watch icon and status. It turns amber when the watch stops syncing.
- **Dropdowns**: every choice is a menu ("Body parts", "Exercise", "Sets", "Dose", "Daily target"…). Lists offer favourites and recent items first. Only notes and "Other…" names are typed.

### Layout

**Today** is a bento:
- The Sleep card (tall) sits beside Steps and Consistency.
- Below them, habit tiles in two columns.
- Then the Workouts list.

At accessibility text sizes everything stacks in one column. Other screens are inset lists on the same background.

### Charts

- **Bars**: lime-to-deep-lime gradient, 3 pt corners.
- **Lines**: lime, with an area fill fading from 28% to nothing.
- **Your usual range**: a teal 16% band.
- **Targets**: a dashed white 50% line.
- **Axes and grid**: secondary text on a white 10% grid.

## Credits and licence

- **Product, design and daily use:** Nemish Shah.
- **Code:** written with Claude (Anthropic).
- **Borrowed ideas:** usual-range baselines, the watch sync check, the backup check, voice logging, the weekly experiment and CI come from [Helios](https://github.com/ShashankKarpal/helios) by Shashank Karpal (MIT). Ideas only; no code was copied.
- **Licence:** the source code is released under the [MIT License](LICENSE).

## For developers

### Repository layout

```text
.
├── HealthTrack.xcodeproj      Open this in Xcode
├── HealthTrack/               App source
│   ├── App/                   Entry point, onboarding, reminders, Siri/Shortcuts actions
│   ├── Core/                  Pure logic: scoring, sleep, baselines, training goals, gym, supplements, export format
│   ├── Health/                Apple Health reading, plus a mock for the simulator
│   ├── Persistence/           SwiftData database (SchemaV1), backup/restore, sample data
│   ├── Features/              Today · Training · Meals · Gym · Supplements · Trends · Weekly · Settings
│   └── Shared/                Theme (design tokens), dropdowns, reusable views
├── HealthTrackTests/          Unit tests (Swift Testing)
├── HealthTrackUITests/        UI, accessibility-audit and screenshot tests
├── Scripts/                   backup-from-iphone.sh
├── Documentation/             Original build spec and the refresh procedure
├── .github/workflows/         `swift test` on every push
├── Package.swift              Lets `swift test` run logic and database tests without a simulator
├── LICENSE                    MIT
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
| `-seedSampleData` | Fills an empty database with 90 days of realistic logs, including gym, protein and four training goals |
| `-mockHealth full` / `empty` / `denied` / `partial` / `noStages` / `unavailable` | Picks the fake Apple Health scenario (the simulator defaults to `full`) |
| `-inMemoryStore` | Uses a throwaway database |
| `-skipOnboarding` | Skips the first-launch screen |
| `-refreshDaysAgo 5` | Pretends the last Xcode refresh was 5 days ago, to see the refresh warning |

## Documents

- [BUILD_STATUS.md](BUILD_STATUS.md): live status, environment, decisions, next action
- [ARCHITECTURE.md](ARCHITECTURE.md): how the app is built, plus the score, sleep, baseline, training and insight formulas
- [DATA_SAFETY.md](DATA_SAFETY.md): where data lives and how not to lose it; read before reinstalling or upgrading
- [TRANSFER_TO_PERSONAL_MAC.md](TRANSFER_TO_PERSONAL_MAC.md): installing on an iPhone (any Mac, same Apple Account), including for other people
- [Documentation/FREE_PROVISIONING_REFRESH.md](Documentation/FREE_PROVISIONING_REFRESH.md): the refresh you repeat about every 6 days
- [TEST_PLAN.md](TEST_PLAN.md): what is tested and how
- [Documentation/HealthTrack_Codex_Master_Build_Spec.md](Documentation/HealthTrack_Codex_Master_Build_Spec.md): the original specification
