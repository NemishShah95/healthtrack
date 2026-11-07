import Foundation
import Testing
@testable import HealthTrack

// MARK: - Usual range (median ± MAD)

@Test func usualRangeNeedsSevenDaysAndIgnoresOneOddNight() throws {
    #expect(UsualRange([50, 52, 48, 51, 49, 50]) == nil)                 // 6 days: too early to say
    let r = try #require(UsualRange([50, 52, 48, 51, 49, 50, 20]))        // one terrible night
    #expect(r.median == 50)
    #expect(r.low > 47 && r.high < 53)                                     // a plain average would sit near 46
    #expect(r.position(of: 50) == .within)
    #expect(r.position(of: 58) == .above)
    #expect(r.position(of: 40) == .below)
    #expect(r.sentence("HRV", value: 58, unit: "ms").hasPrefix("HRV is above your usual range ("))
}

@Test func usualRangeHasAFloorWhenEveryDayIsTheSame() throws {
    let r = try #require(UsualRange(Array(repeating: 60, count: 10)))
    #expect(r.position(of: 61) == .within)                                 // 3% floor: 58.2…61.8
    #expect(r.position(of: 63) == .above)
}

@Test func usualRangeExcludesTheDayItself() throws {
    let cal = calendar()
    var values: [String: Double] = [:]
    for i in 1...10 { values[DayKey.of(cal.date(byAdding: .day, value: -i, to: date("2026-11-07", cal))!, calendar: cal)] = 50 }
    values["2026-11-07"] = 90
    let r = try #require(UsualRange.before("2026-11-07", in: values, calendar: cal))
    #expect(r.days == 10 && r.median == 50)
}

// MARK: - Watch data freshness

@Test func watchDataIsStaleOnlyAfterADayWithNothing() {
    let cal = calendar(), now = date("2026-11-07 09:00", cal)
    #expect(!DataFreshness.isStale(latestWatchDay: "2026-11-07", now: now, calendar: cal))
    #expect(!DataFreshness.isStale(latestWatchDay: "2026-11-06", now: now, calendar: cal))   // last night not synced yet
    #expect(DataFreshness.isStale(latestWatchDay: "2026-11-05", now: now, calendar: cal))
    #expect(!DataFreshness.isStale(latestWatchDay: nil, now: now, calendar: cal))           // never had data
    #expect(DataFreshness.message(latestWatchDay: "2026-11-03", calendar: cal, locale: Locale(identifier: "en_GB"))
            == "No watch data since Tue 3 Nov. Open Zepp to sync, then pull down to refresh.")
}

// MARK: - Weekly experiment

@Test func weeklyExperimentTargetsTheWeakestHabitWithoutAdvice() {
    let day = date("2026-10-26")
    var f = DayFacts()
    f.waterML = 300
    f.mealTimings = [.breakfast: .onTime, .lunch: .onTime, .dinner: .onTime]
    let r = WeeklyReview(weekStart: day, days: [DayRecord(day: day, facts: f)], previousWeek: [], goals: Goals())
    #expect(r.needsAttention.first == .hydration)
    #expect(r.experiment == WeeklyReview.experiment(for: .hydration, goals: Goals()))
    #expect(WeeklyReview(weekStart: day, days: [], previousWeek: [], goals: Goals()).experiment == nil)

    for habit in ScoreComponent.allCases.map(Optional.some) + [nil] {
        let text = WeeklyReview.experiment(for: habit, goals: Goals()).lowercased()
        #expect(!Insights.bannedPhrases.contains { text.contains($0) }, "\(text)")
    }
}

// MARK: - Training goals

private func run(_ km: Double) -> ParsedExercise { ParsedExercise(name: "Run", minutes: 30, distanceKm: km) }

@Test func goalProgressUsesTheWeakestTargetField() {
    let pushups = TrainingGoal(target: ParsedExercise(name: "Push-ups", sets: 3, reps: 15), timesPerWeek: 3)
    #expect(pushups.isMet(by: ParsedExercise(name: "push-ups ", sets: 3, reps: 15)))       // name match ignores case/spaces
    #expect(pushups.progress(of: ParsedExercise(name: "Push-ups", sets: 4, reps: 12)) == 0.8)
    #expect(pushups.progress(of: ParsedExercise(name: "Pull-ups", sets: 3, reps: 15)) == 0)
    #expect(pushups.title == "Push-ups · 3×15" && pushups.cadenceText == "3× a week")
    let anyRun = TrainingGoal(target: ParsedExercise(name: "Run"), timesPerWeek: 2)
    #expect(anyRun.isMet(by: run(1)))                                                       // no numbers: doing it counts
}

@Test func weeklyGoalCountsDaysAndStreaks() {
    let cal = calendar()                       // weeks start Monday
    let now = date("2026-11-07 12:00", cal)    // Saturday
    let goal = TrainingGoal(target: ParsedExercise(name: "Run", distanceKm: 5), timesPerWeek: 2)
    let sessions: [(date: Date, exercises: [ParsedExercise])] = [
        (date("2026-10-20 07:00", cal), [run(5)]), (date("2026-10-22 07:00", cal), [run(6)]),     // week of 19 Oct: met
        (date("2026-10-27 07:00", cal), [run(5)]), (date("2026-10-29 07:00", cal), [run(5.5)]),   // week of 26 Oct: met
        (date("2026-11-03 07:00", cal), [run(5)]), (date("2026-11-03 19:00", cal), [run(5)]),     // this week: one day twice
        (date("2026-11-05 07:00", cal), [run(4)]),                                                // too short
    ]
    let p = GoalProgress.of(goal, sessions: sessions, weeks: 4, now: now, calendar: cal)
    #expect(p.doneThisWeek == 1)
    #expect(p.recentWeeks == [false, true, true, false])
    #expect(p.streak == 2)                     // unfinished current week doesn't break it
    #expect(p.fraction(for: goal) == 0.5)
    #expect(p.best == 1)
}

@Test func milestoneRecordsFirstDayAndBestAttempt() {
    let cal = calendar(), now = date("2026-11-07 12:00", cal)
    let goal = TrainingGoal(target: ParsedExercise(name: "Run", distanceKm: 10), timesPerWeek: 0)
    let early = GoalProgress.of(goal, sessions: [(date("2026-11-01 07:00", cal), [run(6), run(8)])], now: now, calendar: cal)
    #expect(early.achievedOn == nil && early.best == 0.8 && early.fraction(for: goal) == 0.8)
    let done = GoalProgress.of(goal, sessions: [(date("2026-11-04 07:00", cal), [run(10)]), (date("2026-11-06 07:00", cal), [run(12)])],
                               now: now, calendar: cal)
    #expect(done.achievedOn == date("2026-11-04", cal) && done.fraction(for: goal) == 1)
}

@Test func trainingGoalsSurviveInGoalsAndOldGoalsStillDecode() throws {
    var g = Goals()
    g.trainingGoals = [TrainingGoal(target: ParsedExercise(name: "Run", distanceKm: 5), timesPerWeek: 3)]
    let decoded = try JSONDecoder().decode(Goals.self, from: JSONEncoder().encode(g))
    #expect(decoded.trainingGoals == g.trainingGoals)
    let old = try JSONDecoder().decode(Goals.self, from: Data(#"{"waterTargetML": 3000}"#.utf8))
    #expect(old.trainingGoals.isEmpty && old.waterTargetML == 3000)
}

@Test func catalogueDrivesTheDropdowns() {
    #expect(ExerciseCatalog.kind(of: "run") == .cardio)
    #expect(ExerciseCatalog.kind(of: "Mystery move", sample: ParsedExercise(name: "Mystery move", minutes: 20)) == .cardio)
    #expect(ExerciseCatalog.kind(of: "Mystery move", sample: ParsedExercise(name: "Mystery move", sets: 3, reps: 10)) == .bodyweight)
    #expect(ExerciseCatalog.names(for: [.legs]).first == "Squat")
    #expect(Set(ExerciseCatalog.names(for: [])).count == ExerciseCatalog.all.count)          // every exercise, once
    #expect(ExerciseField.weight.options(including: 102.1).contains(102.1))                   // old values stay pickable
    // An old "Plank 3x1" keeps its reps visible even though planks are timed.
    #expect(ParsedExercise(name: "Plank", sets: 3, reps: 1).visibleFields == [.sets, .reps, .minutes])
    #expect(ExerciseCatalog.starter("Run") == ParsedExercise(name: "Run", minutes: 30))
}
