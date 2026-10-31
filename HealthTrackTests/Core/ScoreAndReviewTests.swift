import Foundation
import Testing
@testable import HealthTrack

// MARK: - Behaviour score

@Test func defaultWeightsCoverEveryComponentAndSumTo100() {
    #expect(Set(ScoreComponent.defaultWeights.keys) == Set(ScoreComponent.allCases))
    #expect(ScoreComponent.defaultWeights.values.reduce(0, +) == 100)
}

@Test func perfectDayScoresOne() {
    let f = DayFacts(bedtime: .init(23, 10), wakeTime: .init(6, 50), asleepMinutes: 450,
                     mealTimings: [.breakfast: .onTime, .lunch: .onTime, .dinner: .onTime],
                     waterML: 2600, supplementStatuses: [.taken, .taken], steps: 9000, workoutsInLast7Days: 4)
    let c = BehaviorScore.components(f, goals: Goals())
    #expect(c.count == 6 && c.values.allSatisfy { $0 == 1 })
    #expect(BehaviorScore.score(c) == 1)
}

@Test func missingComponentsAreLeftOutNotZeroed() throws {
    // Hydration (15) at 100% and meals (20) at 50%: (15 + 10) / 35
    let score = try #require(BehaviorScore.score([.hydration: 1, .meals: 0.5]))
    #expect(abs(score - 25.0 / 35.0) < 1e-9)
    #expect(BehaviorScore.score([:]) == nil)
    // A day with no HealthKit data and nothing logged: only water (0 ml) is judged.
    #expect(BehaviorScore.components(DayFacts(), goals: Goals()) == [.hydration: 0])
}

@Test func sleepComponentHandlesBedtimeAfterMidnight() {
    var f = DayFacts(bedtime: .init(23, 25), wakeTime: .init(7), asleepMinutes: 400)  // target 23:00 ±30, 7h
    #expect(BehaviorScore.components(f, goals: Goals())[.sleep] == 2.0 / 3.0)
    f.bedtime = .init(0, 20)
    #expect(BehaviorScore.components(f, goals: Goals())[.sleep] == 1.0 / 3.0)
}

@Test func zeroTargetsNeverDivideByZero() {
    var g = Goals()
    g.waterTargetML = 0
    g.stepTarget = 0
    g.workoutsPerWeek = 0
    let c = BehaviorScore.components(DayFacts(waterML: 500, steps: 100, workoutsInLast7Days: 1), goals: g)
    #expect(c.isEmpty)
}

// MARK: - Weekly review

@Test func weekBoundaryFollowsFirstWeekdayAcrossDST() {
    let ny = calendar("America/New_York", firstWeekday: 2)  // US clocks go back 2026-11-01
    let week = WeeklyReview.week(containing: date("2026-11-01 12:00", ny), calendar: ny)
    #expect(week.start == date("2026-10-26", ny))
    #expect(week.end == date("2026-11-02", ny))
    let sundayFirst = calendar("America/New_York", firstWeekday: 1)
    #expect(WeeklyReview.week(containing: date("2026-11-01 12:00", sundayFirst), calendar: sundayFirst).start == date("2026-11-01", sundayFirst))
}

@Test func reviewWithPartialData() {
    let cal = calendar(), start = date("2026-10-26", cal)
    let days = (0..<7).map { i in
        var f = DayFacts()
        f.waterML = i < 3 ? 2600 : 500
        f.mealTimings = [.breakfast: .onTime, .lunch: .onTime, .dinner: i < 2 ? .late : .onTime]
        if i != 3 { f.bedtime = .init(23); f.wakeTime = .init(7); f.asleepMinutes = 440 }  // one night missing
        return DayRecord(day: cal.date(byAdding: .day, value: i, to: start)!, facts: f,
                         energy: i.isMultiple(of: 2) ? 4 : nil, workouts: i < 4 ? 1 : 0)
    }
    let r = WeeklyReview(weekStart: start, days: days, previousWeek: [], goals: Goals())
    #expect(r.days == 7)
    #expect(r.nightsWithSleep == 6 && r.bedtimeHits == 6 && r.wakeHits == 6)
    #expect(r.averageSleepMinutes == 440)
    #expect(r.mealsLogged == 21 && r.mealsEvaluated == 21)
    #expect(r.mealsOnTimeRate == 19.0 / 21.0)
    #expect(r.lateDinners == 2)
    #expect(r.waterTargetDays == 3)
    #expect(r.workouts == 4 && r.workoutTarget == 4)
    #expect(r.averageSteps == nil)
    #expect(r.supplementAdherence == nil)
    #expect(r.averageEnergy == 4)
    #expect(r.hrvTrend == nil)
    #expect(r.bestHabit == .sleep)
    #expect(r.needsAttention == [.hydration])
}

@Test func emptyWeekProducesEmptyReview() {
    let r = WeeklyReview(weekStart: date("2026-10-26"), days: [], previousWeek: [], goals: Goals())
    #expect(r.consistency == nil && r.mealsOnTimeRate == nil && r.averageSleepMinutes == nil)
    #expect(r.bestHabit == nil && r.needsAttention.isEmpty)
}

@Test func reviewTrendsCompareWithPreviousWeek() {
    let day = date("2026-10-26")
    let previous = (0..<7).map { _ in DayRecord(day: day, facts: DayFacts(), hrv: 50, restingHR: 60) }
    let current = (0..<7).map { _ in DayRecord(day: day, facts: DayFacts(), hrv: 56, restingHR: 60) }
    let r = WeeklyReview(weekStart: day, days: current, previousWeek: previous, goals: Goals())
    #expect(r.hrvTrend == .up)
    #expect(r.restingHRTrend == .stable)
}

// MARK: - Trends & insights

@Test func trendDirectionThresholdsAndMinimumSamples() {
    #expect(Trend.direction(current: [53, 53, 53], previous: [50, 50, 50]) == .up)
    #expect(Trend.direction(current: [51, 51, 51], previous: [50, 50, 50]) == .stable)
    #expect(Trend.direction(current: [40, 40, 40], previous: [50, 50, 50]) == .down)
    #expect(Trend.direction(current: [60, 60], previous: [50, 50, 50]) == nil)
    #expect(Trend.direction(current: [1, 1, 1], previous: [0, 0, 0]) == nil)
}

private let en = Locale(identifier: "en_US")

@Test func insightsNeedMinimumSamples() throws {
    let early = Array(repeating: (dinner: TimeOfDay(19), asleepMinutes: 450.0), count: 5)
    let late = Array(repeating: (dinner: TimeOfDay(21), asleepMinutes: 420.0), count: 5)
    #expect(Insights.sleepVsDinnerTime(Array(early.prefix(4)) + late, locale: en) == nil)
    let sleep = try #require(Insights.sleepVsDinnerTime(early + late, locale: en))
    #expect(sleep.text.hasPrefix("Your average sleep was 30 minutes longer on nights when dinner was before 8:30"))

    #expect(Insights.hrvChange(last30: Array(repeating: 56, count: 13), prior30: Array(repeating: 50, count: 14)) == nil)
    #expect(Insights.hrvChange(last30: Array(repeating: 56, count: 14), prior30: Array(repeating: 50, count: 14))?.text
            == "Your 30-day HRV average is 12% above the prior 30 days.")

    #expect(Insights.bedtimeTargetRate(hits: 5, nights: 6) == nil)
    #expect(Insights.bedtimeTargetRate(hits: 23, nights: 30)?.text == "You met your bedtime target on 77% of nights this month.")
    #expect(Insights.supplementLogged(name: "Magnesium", taken: 26, scheduled: 30)?.text == "Magnesium was logged on 26 of 30 scheduled days.")
}

@Test func insightsNeverUseCausalOrDiagnosticLanguage() {
    let e = Array(repeating: (dinner: TimeOfDay(19), asleepMinutes: 450.0), count: 5)
    let l = Array(repeating: (dinner: TimeOfDay(21), asleepMinutes: 420.0), count: 5)
    let flipped = l.map { (dinner: $0.dinner, asleepMinutes: 480.0) }
    let texts = [
        Insights.sleepVsDinnerTime(e + l, locale: en), Insights.sleepVsDinnerTime(e + flipped, locale: en),
        Insights.hrvChange(last30: Array(repeating: 56, count: 14), prior30: Array(repeating: 50, count: 14)),
        Insights.hrvChange(last30: Array(repeating: 44, count: 14), prior30: Array(repeating: 50, count: 14)),
        Insights.hrvChange(last30: Array(repeating: 50, count: 14), prior30: Array(repeating: 50, count: 14)),
        Insights.bedtimeTargetRate(hits: 20, nights: 30),
        Insights.supplementLogged(name: "Vitamin D", taken: 7, scheduled: 7),
    ].map { $0?.text.lowercased() }
    #expect(texts.allSatisfy { $0 != nil })
    for text in texts.compactMap({ $0 }) {
        #expect(!Insights.bannedPhrases.contains { text.contains($0) }, "\(text)")
    }
}
