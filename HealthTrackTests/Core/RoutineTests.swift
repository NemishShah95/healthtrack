import Foundation
import Testing
@testable import HealthTrack

// MARK: - Time of day

@Test func signedMinutesWrapAroundMidnight() {
    #expect(TimeOfDay(23, 50).signedMinutes(to: TimeOfDay(0, 10)) == 20)
    #expect(TimeOfDay(0, 10).signedMinutes(to: TimeOfDay(23, 50)) == -20)
    #expect(TimeOfDay(8).signedMinutes(to: TimeOfDay(9, 30)) == 90)
}

@Test func timeOfDayEncodesAsHHmm() throws {
    let data = try JSONEncoder().encode([TimeOfDay(7, 5)])
    #expect(String(decoding: data, as: UTF8.self) == #"["07:05"]"#)
    #expect(try JSONDecoder().decode([TimeOfDay].self, from: data) == [TimeOfDay(7, 5)])
    #expect(throws: DecodingError.self) { try JSONDecoder().decode([TimeOfDay].self, from: Data(#"["25:00"]"#.utf8)) }
}

@Test func timeOnSkippedDSTHourStillLandsOnThatDay() {
    let cal = calendar()  // London skips 01:00–02:00 on 2026-03-29
    let d = TimeOfDay(1, 30).on(date("2026-03-29", cal), in: cal)
    #expect(cal.isDate(d, inSameDayAs: date("2026-03-29", cal)))
    #expect(TimeOfDay(of: d, in: cal).hour == 2)
}

// MARK: - Meals

let breakfast = MealWindow.defaults[.breakfast]!  // 07:30–09:30

@Test func mealWindowClassification() {
    #expect(MealRoutine.timing(loggedTimes: [.init(8)], window: breakfast, now: nil) == .onTime)
    #expect(MealRoutine.timing(loggedTimes: [.init(7, 30)], window: breakfast, now: nil) == .onTime)
    #expect(MealRoutine.timing(loggedTimes: [.init(9, 30)], window: breakfast, now: nil) == .onTime)
    #expect(MealRoutine.timing(loggedTimes: [.init(6)], window: breakfast, now: nil) == .early)
    #expect(MealRoutine.timing(loggedTimes: [.init(10)], window: breakfast, now: nil) == .late)
    #expect(MealRoutine.timing(loggedTimes: [.init(10), .init(8)], window: breakfast, now: nil) == .onTime)
}

@Test func unloggedMealIsPendingUntilItsWindowEnds() {
    #expect(MealRoutine.timing(loggedTimes: [], window: breakfast, now: .init(9)) == .pending)
    #expect(MealRoutine.timing(loggedTimes: [], window: breakfast, now: .init(10)) == .skipped)
    #expect(MealRoutine.timing(loggedTimes: [], window: breakfast, now: nil) == .skipped)
}

@Test func mealConsistency() {
    #expect(MealRoutine.consistency([.onTime, .late, .skipped]) == 0.5)
    #expect(MealRoutine.consistency([.onTime, .pending]) == 1)
    #expect(MealRoutine.consistency([.pending, .pending]) == nil)
}

@Test func foodLinesParseNamesAndGrams() {
    let foods = MealRoutine.parseFoods("- oats 80 g\nbanana 120g, yogurt 180 grams\n• egg 2\nRice 1.5 G\n\n  ")
    #expect(foods == [
        .init(name: "oats", grams: 80), .init(name: "banana", grams: 120), .init(name: "yogurt", grams: 180),
        .init(name: "egg 2", grams: nil), .init(name: "Rice", grams: 1.5),
    ])
}

@Test func zeroOrInvalidGramsMeanNoQuantity() {
    #expect(MealRoutine.cleanGrams(0) == nil)
    #expect(MealRoutine.cleanGrams(-5) == nil)
    #expect(MealRoutine.cleanGrams(.nan) == nil)
    #expect(MealRoutine.cleanGrams(12.5) == 12.5)
    #expect(MealRoutine.parseFoods("rice 0 g") == [.init(name: "rice", grams: nil)])
    #expect(MealRoutine.parseFoods("80 g") == [.init(name: "80 g", grams: nil)])
}

@Test func largeNumberOfFoodItems() {
    let foods = MealRoutine.parseFoods((1...500).map { "food #\($0) 10 g" }.joined(separator: "\n"))
    #expect(foods.count == 500)
    #expect(foods.allSatisfy { $0.grams == 10 })
}

// MARK: - Water

@Test func rapidDuplicateWaterTapsAreDetected() {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(!Hydration.isDuplicateTap(previousML: nil, previousAt: nil, amountML: 250, at: t0))
    #expect(Hydration.isDuplicateTap(previousML: 250, previousAt: t0, amountML: 250, at: t0 + 0.4))
    #expect(!Hydration.isDuplicateTap(previousML: 250, previousAt: t0, amountML: 500, at: t0 + 0.4))
    #expect(!Hydration.isDuplicateTap(previousML: 250, previousAt: t0, amountML: 250, at: t0 + 2))
}

@Test func waterProgressAndTarget() {
    #expect(Hydration.progressText(totalML: 1900, targetML: 2500) == "1.9 / 2.5 L")
    #expect(BehaviorScore.ratio(1900, 2500) == 0.76)
    #expect(BehaviorScore.ratio(3000, 2500) == 1)
    #expect(BehaviorScore.ratio(1000, 0) == nil)
}

// MARK: - Supplements

@Test func weekdayScheduleWithStartAndEnd() {
    let cal = calendar()
    let rule = SupplementRule(weekdays: [2, 4, 6], startDate: date("2026-10-01", cal), endDate: date("2026-10-31", cal), isActive: true)
    #expect(rule.isScheduled(on: date("2026-10-26 08:00", cal), calendar: cal))   // Monday
    #expect(!rule.isScheduled(on: date("2026-10-27", cal), calendar: cal))        // Tuesday
    #expect(rule.isScheduled(on: date("2026-10-30 23:59", cal), calendar: cal))   // Friday, before end
    #expect(!rule.isScheduled(on: date("2026-09-28", cal), calendar: cal))        // Monday before start
    #expect(!rule.isScheduled(on: date("2026-11-02", cal), calendar: cal))        // Monday after end

    var paused = rule
    paused.isActive = false
    #expect(!paused.isScheduled(on: date("2026-10-26", cal), calendar: cal))

    let daily = SupplementRule(weekdays: [], startDate: date("2026-10-01", cal), endDate: nil, isActive: true)
    #expect((0..<14).allSatisfy { daily.isScheduled(on: cal.date(byAdding: .day, value: $0, to: date("2026-10-20", cal))!, calendar: cal) })
}

@Test func scheduleFollowsTheLocalCalendarDay() {
    let london = calendar(), kolkata = calendar("Asia/Kolkata")
    let rule = SupplementRule(weekdays: [2], startDate: date("2026-01-01", london), endDate: nil, isActive: true)  // Mondays
    let instant = date("2026-10-26 23:30", london)  // Monday in London, Tuesday 05:00 in Kolkata
    #expect(rule.isScheduled(on: instant, calendar: london))
    #expect(!rule.isScheduled(on: instant, calendar: kolkata))
}

@Test func pendingDoseFromAPastDayIsMissed() {
    let cal = calendar(), today = date("2026-10-31 12:00", cal)
    #expect(SupplementAdherence.resolved(.pending, scheduledDay: date("2026-10-30", cal), today: today, calendar: cal) == .missed)
    #expect(SupplementAdherence.resolved(.pending, scheduledDay: date("2026-10-31", cal), today: today, calendar: cal) == .pending)
    #expect(SupplementAdherence.resolved(.taken, scheduledDay: date("2026-10-01", cal), today: today, calendar: cal) == .taken)
}

@Test func supplementAdherenceStreakAndMostMissed() {
    #expect(SupplementAdherence.rate([.taken, .taken, .skipped, .missed]) == 0.5)
    #expect(SupplementAdherence.rate([]) == nil)

    #expect(SupplementAdherence.streak(daysNewestFirst: [[.taken, .pending], [.taken, .taken], [], [.taken], [.missed, .taken], [.taken]]) == 2)
    #expect(SupplementAdherence.streak(daysNewestFirst: [[.skipped], [.taken]]) == 0)
    #expect(SupplementAdherence.streak(daysNewestFirst: []) == 0)

    #expect(SupplementAdherence.mostMissed([("Iron", .missed), ("Iron", .skipped), ("Magnesium", .missed), ("Vitamin D", .taken)]) == "Iron")
    #expect(SupplementAdherence.mostMissed([("Zinc", .missed), ("Iron", .missed)]) == "Iron")
    #expect(SupplementAdherence.mostMissed([("Vitamin D", .taken)]) == nil)
}

@Test func oneTapMealPicksTheMealYouMostLikelyMean() {
    let w = MealWindow.defaults
    #expect(MealRoutine.nextMeal(logged: [], windows: w, now: .init(21, 40)) == .dinner)
    #expect(MealRoutine.nextMeal(logged: [], windows: w, now: .init(13)) == .lunch)
    #expect(MealRoutine.nextMeal(logged: [], windows: w, now: .init(6)) == .breakfast)
    #expect(MealRoutine.nextMeal(logged: [.breakfast, .dinner], windows: w, now: .init(13)) == .lunch)
    #expect(MealRoutine.nextMeal(logged: [.dinner], windows: w, now: .init(22)) == .lunch)
    #expect(MealRoutine.nextMeal(logged: [.breakfast, .lunch, .dinner], windows: w, now: .init(13)) == nil)
}
