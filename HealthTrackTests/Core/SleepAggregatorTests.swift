import Foundation
import Testing
@testable import HealthTrack

private let cal = calendar()

private func s(_ start: String, _ end: String, _ stage: SleepStage, _ source: String = "zepp") -> SleepSample {
    SleepSample(start: date(start, cal), end: date(end, cal), stage: stage, source: source)
}

private func nights(_ samples: [SleepSample]) -> [NightSummary] {
    SleepAggregator.nights(from: samples, calendar: cal)
}

@Test func crossMidnightNightBelongsToWakeDay() throws {
    let result = nights([
        s("2026-10-20 23:10", "2026-10-21 01:00", .core),
        s("2026-10-21 01:00", "2026-10-21 02:30", .deep),
        s("2026-10-21 02:30", "2026-10-21 02:45", .awake),
        s("2026-10-21 02:45", "2026-10-21 04:00", .rem),
        s("2026-10-21 04:00", "2026-10-21 06:50", .core),
    ])
    #expect(result.count == 1)
    let n = try #require(result.first)
    #expect(n.night == date("2026-10-21", cal))
    #expect(n.sleepStart == date("2026-10-20 23:10", cal))
    #expect(n.finalWake == date("2026-10-21 06:50", cal))
    #expect(n.asleep == 445 * 60)   // 7h40 span minus 15 min awake
    #expect(n.awake == 15 * 60)
    #expect(n.inBed == 460 * 60)
    #expect(n.interruptions == 1)
    #expect(n.core == 280 * 60.0)
    #expect(n.deep == 90 * 60.0)
    #expect(n.rem == 75 * 60.0)
}

@Test func overlappingSamplesAndSourcesAreNotDoubleCounted() throws {
    let n = try #require(nights([
        s("2026-10-20 23:00", "2026-10-21 03:00", .core),
        s("2026-10-21 02:00", "2026-10-21 04:00", .core),        // overlapping duplicate, same source
        s("2026-10-21 03:00", "2026-10-21 07:00", .deep),
        s("2026-10-20 22:30", "2026-10-21 07:30", .asleepUnspecified, "phone"),
        s("2026-10-20 22:00", "2026-10-21 07:45", .inBed, "phone"),
    ]).first)
    #expect(n.asleep == 8 * 3600)                  // staged source only, overlap counted once
    #expect(n.deep != nil)
    #expect(n.inBed == 9 * 3600 + 45 * 60)         // 22:00–07:45 from the phone's in-bed sample
}

@Test func napsDoNotReplaceTheMainSleep() {
    let result = nights([
        s("2026-10-20 23:00", "2026-10-21 07:00", .core),
        s("2026-10-21 14:00", "2026-10-21 14:40", .core),        // afternoon nap, same day
        s("2026-10-21 19:00", "2026-10-21 19:30", .core),        // evening nap → next day's window
        s("2026-10-21 23:30", "2026-10-22 06:30", .core),
    ])
    #expect(result.map(\.night) == [date("2026-10-21", cal), date("2026-10-22", cal)])
    #expect(result.map(\.asleep) == [8 * 3600.0, 7 * 3600.0])
}

@Test func missingStageDataGivesNilStages() throws {
    let n = try #require(nights([s("2026-10-20 23:00", "2026-10-21 06:00", .asleepUnspecified)]).first)
    #expect(n.asleep == 7 * 3600)
    #expect(n.core == nil && n.deep == nil && n.rem == nil)
}

@Test func noDataOrInvalidSamplesGiveNoNights() {
    #expect(nights([]).isEmpty)
    #expect(nights([s("2026-10-21 07:00", "2026-10-20 23:00", .core)]).isEmpty)
    #expect(nights([s("2026-10-20 22:00", "2026-10-21 07:00", .inBed)]).isEmpty)
}

@Test func daylightSavingNightsUseRealElapsedTime() throws {
    // London: clocks go back on 2026-10-25 (an hour longer) and forward on 2026-03-29 (an hour shorter).
    let fallBack = try #require(nights([s("2026-10-24 23:00", "2026-10-25 07:00", .core)]).first)
    #expect(fallBack.asleep == 9 * 3600)
    #expect(fallBack.night == date("2026-10-25", cal))
    let springForward = try #require(nights([s("2026-03-28 23:00", "2026-03-29 07:00", .core)]).first)
    #expect(springForward.asleep == 7 * 3600)
}

@Test func nightAssignmentFollowsTheLocalTimeZone() {
    let wake = date("2026-10-21 17:30", cal)  // 17:30 London = 23:00 Kolkata
    #expect(SleepAggregator.nightDate(wake: wake, calendar: cal) == date("2026-10-21", cal))
    let kolkata = calendar("Asia/Kolkata")
    #expect(SleepAggregator.nightDate(wake: wake, calendar: kolkata) == date("2026-10-22", kolkata))
}
