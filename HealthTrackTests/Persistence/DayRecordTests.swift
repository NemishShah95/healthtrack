import Foundation
import SwiftData
import Testing
@testable import HealthTrack

@MainActor
@Suite struct DayRecordTests {
    let cal = calendar()
    let now = date("2026-10-28 10:00", calendar())   // Wednesday morning

    func context() throws -> ModelContext { ModelContext(try Persistence.makeContainer(inMemory: true)) }

    var health: HealthSnapshot {
        HealthSnapshot(
            sleepSamples: [SleepSample(start: date("2026-10-27 23:10", cal), end: date("2026-10-28 06:55", cal), stage: .core, source: "w")],
            steps: ["2026-10-27": 9000, "2026-10-28": 1200],
            hrv: ["2026-10-28": 52],
            workouts: [WorkoutSummary(start: date("2026-10-26 18:00", cal), end: date("2026-10-26 18:45", cal), activityName: "Running")])
    }

    @Test func combinesLogsAndHealthForToday() throws {
        let ctx = try context()
        ctx.logMeal(.breakfast, at: date("2026-10-28 08:00", cal), calendar: cal)
        ctx.logWater(500, at: date("2026-10-28 09:00", cal), now: date("2026-10-28 09:00", cal))
        ctx.checkIn(onDay: "2026-10-28").energy = 4

        let today = try #require(ctx.dayRecords(from: now, through: now, health: health, goals: Goals(), now: now, calendar: cal).first)
        #expect(today.facts.bedtime == TimeOfDay(23, 10) && today.facts.wakeTime == TimeOfDay(6, 55))
        #expect(today.facts.asleepMinutes == 465)
        #expect(today.facts.mealTimings == [.breakfast: .onTime, .lunch: .pending, .dinner: .pending])
        #expect(today.facts.waterML == 500)
        #expect(today.facts.steps == 1200)
        #expect(today.facts.workoutsInLast7Days == 1)
        #expect(today.hrv == 52 && today.energy == 4 && today.workouts == 0)
    }

    @Test func pastDaysJudgeMealsAndFutureDaysAreClipped() throws {
        let ctx = try context()
        ctx.logMeal(.dinner, at: date("2026-10-26 22:15", cal), calendar: cal)   // late dinner, first log ever
        let records = ctx.dayRecords(from: date("2026-10-24", cal), through: date("2026-10-31", cal),
                                     health: health, goals: Goals(), now: now, calendar: cal)
        #expect(records.count == 5)                                   // 24 … 28; 29–31 are in the future
        #expect(records[0].facts.mealTimings.isEmpty)                 // before tracking started
        #expect(records[2].facts.mealTimings == [.breakfast: .skipped, .lunch: .skipped, .dinner: .late])
        #expect(records[2].workouts == 1)
    }

    @Test func noHealthAccessLeavesHealthComponentsOut() throws {
        let ctx = try context()
        ctx.logWater(2500, at: now, now: now)
        let record = try #require(ctx.dayRecords(from: now, through: now, health: HealthSnapshot(), goals: Goals(), now: now, calendar: cal).first)
        let components = BehaviorScore.components(record.facts, goals: Goals())
        #expect(components[.sleep] == nil && components[.exercise] == nil && components[.movement] == nil)
        #expect(components[.hydration] == 1)
    }
}
