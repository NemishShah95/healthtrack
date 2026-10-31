# Build Status

_Last updated: 2026-10-31_

## Current Milestone
M0, Environment and Repository: **complete**
M1, Xcode App Skeleton: **blocked: Xcode is not installed** (see Next Action)

## Build
Core logic (`swift build`): PASS
iOS app (`xcodebuild`): not yet possible (no Xcode)

## Tests
Core logic (`swift test`): 41 passed, 0 failed

## Simulator QA
Pending (requires Xcode)

## Environment (development Mac)

| Item | Finding |
| --- | --- |
| Hardware | Apple M4 Pro |
| macOS | 26.6.2 (25G83) |
| Xcode | **Not installed**. `xcode-select` points at Command Line Tools |
| Command Line Tools | 16.4 |
| Swift | 6.1.2 (from Command Line Tools) |
| Git | 2.39.5 (Apple Git-154) |
| iOS Simulator runtimes | None (they come with Xcode) |
| iPhone simulator device types | None (they come with Xcode) |
| Xcode signing teams | N/A. Not needed on this Mac: signing happens on the personal Mac |
| Free disk space | ~30 GB (93% used). Tight for Xcode plus a simulator runtime |

What works without Xcode: compiling and testing the Foundation-only `HealthTrack/Core` logic via `Package.swift`.
What doesn't: SwiftData `@Model` macros, the iOS SDK, the simulator, and `xcodebuild`.

## Decisions

| Decision | Value |
| --- | --- |
| Project location | `~/Documents/healthjournal` (the spec suggested `~/Documents/HealthTrack`; the product owner chose this folder) |
| Git | Local repository only. The future home is the product owner's personal GitHub account. Never push to GitLab |
| Bundle identifier | `com.nemishshah.healthtrack` (permanent) |
| Deployment target | iOS 17.0 (the minimum for SwiftData) |
| Swift language mode | Swift 5 (avoids strict-concurrency friction with SwiftData/HealthKit) |

## Features
- [x] M0 Repository, docs, environment inspection
- [x] Core logic (built early while M1 is blocked): meal windows, water, supplement schedules and adherence, sleep aggregation, behaviour score, weekly review, trends, insights, reinstall dates, JSON/CSV export format
- [ ] M1 Xcode project, tab navigation
- [ ] M2 SwiftData persistence
- [ ] M3 HealthKit abstraction
- [ ] M4 Sleep and recovery (UI and HealthKit wiring; aggregation logic done)
- [ ] M5 Meals and food
- [ ] M6 Water
- [ ] M7 Supplements
- [ ] M8 Activity
- [ ] M9 Today dashboard
- [ ] M10 Behaviour score (UI; logic done)
- [ ] M11 Trends
- [ ] M12 Weekly review (UI; logic done)
- [ ] M13 Insights (UI; logic done)
- [ ] M14 Reinstall reminder (UI and notifications; date logic done)
- [ ] M15 Export and backup (share sheet and import; format done)
- [ ] M16 Full QA
- [ ] M17 Transfer package
- [ ] M18 Personal Mac installation (product owner)
- [ ] M19 Real data validation (product owner and engineer)

## Known Issues
- Commits so far use this Mac's global (work) git identity. For a personal project, run `git config user.email <personal email>` in this folder and re-author the commits before the first push.

## Next Action
BLOCKED ON: Xcode is not installed.

WHAT YOU NEED TO DO:
1. Free up disk space. The biggest candidates are `~/.colima` (40 GB) and `~/Library/Caches` (19 GB).
2. Install Xcode from the Mac App Store (or developer.apple.com/download).
3. Open Xcode once, accept the license, and tick iOS when it asks which platforms to install.
4. Run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

WHEN COMPLETE: say "Xcode installed". M1 (Xcode project and simulator launch) resumes from there.
