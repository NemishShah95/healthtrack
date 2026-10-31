import Foundation
import Testing
@testable import HealthTrack

private let cal = calendar()
private let now = date("2026-10-31 12:00", cal)

private func snapshot(_ scenario: MockHealthDataProvider.Scenario, days: Int = 90) async -> HealthSnapshot {
    let provider = MockHealthDataProvider(scenario: scenario, historyDays: days, now: now)
    return await provider.snapshot(from: cal.date(byAdding: .day, value: -89, to: date("2026-10-31", cal))!,
                                   to: date("2026-11-01", cal), calendar: cal)
}

@Test func fullScenarioHas90DaysOfEveryMetric() async {
    let s = await snapshot(.full)
    let nights = s.nights(calendar: cal)
    #expect(s.steps.count == 90 && s.hrv.count == 90 && s.restingHR.count == 90)
    #expect(nights.count == 90)
    #expect(nights.values.allSatisfy { $0.deep != nil && $0.asleep >= 6 * 3600 && $0.asleep <= 8.5 * 3600 })
    #expect(nights.values.allSatisfy { $0.inBed >= $0.asleep + $0.awake })
    #expect(s.workouts.count > 30)
}

@Test func mockDataIsDeterministic() async {
    let a = await snapshot(.full), b = await snapshot(.full)
    #expect(a.steps == b.steps && a.workouts == b.workouts && a.sleepSamples.count == b.sleepSamples.count)
}

@Test func sparseAndDeniedScenarios() async {
    #expect(await snapshot(.empty).steps.isEmpty)
    #expect(await snapshot(.denied).sleepSamples.isEmpty)

    let partial = await snapshot(.partial)
    #expect(!partial.steps.isEmpty && partial.sleepSamples.isEmpty && partial.hrv.isEmpty)

    let noStages = await snapshot(.noStages).nights(calendar: cal)
    #expect(!noStages.isEmpty && noStages.values.allSatisfy { $0.deep == nil && $0.rem == nil })

    let oneDay = await snapshot(.full, days: 1)
    #expect(oneDay.steps.count == 1 && oneDay.nights(calendar: cal).count == 1)

    #expect(await MockHealthDataProvider(scenario: .unavailable).accessState() == .unavailable)
}
