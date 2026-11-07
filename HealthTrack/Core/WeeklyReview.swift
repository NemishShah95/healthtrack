import Foundation

/// Everything known about one day, for weekly aggregation.
struct DayRecord: Sendable {
    var day: Date
    var facts: DayFacts
    var hrv: Double? = nil
    var restingHR: Double? = nil
    var energy: Int? = nil
    /// Workouts that day: the larger of watch workouts and journaled gym sessions, so one session is never counted twice.
    var workouts = 0
    /// Grams of protein logged; nil when nothing was logged that day.
    var protein: Int? = nil
    var gymSessions = 0
    var bodyParts: [BodyPart] = []
}

struct WeeklyReview: Equatable, Sendable {
    static let attentionThreshold = 0.7

    var weekStart: Date
    var days: Int
    var consistency: Double?
    var averageSleepMinutes: Double?
    var nightsWithSleep: Int
    var bedtimeHits: Int
    var wakeHits: Int
    var hrvTrend: TrendDirection?
    var restingHRTrend: TrendDirection?
    var mealsOnTimeRate: Double?
    var mealsLogged: Int
    var mealsEvaluated: Int
    var lateDinners: Int
    var workouts: Int
    var workoutTarget: Int
    var averageSteps: Double?
    var waterTargetDays: Int
    var supplementAdherence: Double?
    var averageEnergy: Double?
    var averageProtein: Double?
    var proteinDaysLogged: Int
    var proteinTargetDays: Int
    var gymSessions: Int
    /// How many sessions trained each body part.
    var bodyParts: [BodyPart: Int]
    var bestHabit: ScoreComponent?
    var needsAttention: [ScoreComponent]
    /// One small, habit-level thing to try next week, aimed at the weakest habit. nil for an empty week.
    var experiment: String?

    /// The week (per the calendar's first weekday) containing `date`.
    static func week(containing date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 86400)
    }

    init(weekStart: Date, days records: [DayRecord], previousWeek: [DayRecord], goals: Goals) {
        let facts = records.map(\.facts)
        let components = facts.map { BehaviorScore.components($0, goals: goals) }

        self.weekStart = weekStart
        days = records.count
        consistency = components.compactMap { BehaviorScore.score($0) }.mean

        averageSleepMinutes = facts.compactMap(\.asleepMinutes).mean
        nightsWithSleep = facts.filter { $0.asleepMinutes != nil }.count
        bedtimeHits = facts.compactMap(\.bedtime).filter(goals.isBedtimeOnTarget).count
        wakeHits = facts.compactMap(\.wakeTime).filter(goals.isWakeOnTarget).count
        hrvTrend = Trend.direction(current: records.compactMap(\.hrv), previous: previousWeek.compactMap(\.hrv))
        restingHRTrend = Trend.direction(current: records.compactMap(\.restingHR), previous: previousWeek.compactMap(\.restingHR))

        let judged = facts.flatMap(\.mealTimings.values).filter { $0 != .pending }
        mealsEvaluated = judged.count
        mealsLogged = judged.filter(\.isLogged).count
        mealsOnTimeRate = judged.isEmpty ? nil : Double(judged.filter { $0 == .onTime }.count) / Double(judged.count)
        lateDinners = facts.filter { $0.mealTimings[.dinner] == .late }.count

        workouts = records.reduce(0) { $0 + $1.workouts }
        workoutTarget = goals.workoutsPerWeek
        averageSteps = facts.compactMap(\.steps).map(Double.init).mean
        waterTargetDays = facts.filter { ($0.waterML ?? 0) >= goals.waterTargetML }.count
        supplementAdherence = SupplementAdherence.rate(facts.flatMap(\.supplementStatuses))
        averageEnergy = records.compactMap(\.energy).map(Double.init).mean
        let protein = records.compactMap(\.protein)
        averageProtein = protein.map(Double.init).mean
        proteinDaysLogged = protein.count
        proteinTargetDays = protein.filter { $0 >= goals.proteinTargetGrams }.count
        gymSessions = records.reduce(0) { $0 + $1.gymSessions }
        bodyParts = records.flatMap(\.bodyParts).reduce(into: [:]) { $0[$1, default: 0] += 1 }

        // Best first; ties go to the higher-weighted component (allCases order).
        let ranked = ScoreComponent.allCases.enumerated()
            .compactMap { i, c in components.compactMap { $0[c] }.mean.map { (i, c, $0) } }
            .sorted { ($0.2, -$0.0) > ($1.2, -$1.0) }
        bestHabit = ranked.first?.1
        needsAttention = ranked.dropFirst().reversed()
            .filter { $0.2 < Self.attentionThreshold }
            .prefix(2)
            .map(\.1)
        experiment = records.isEmpty ? nil : Self.experiment(for: needsAttention.first, goals: goals)
    }

    /// Habits only, never health advice; checked against `Insights.bannedPhrases` by tests. Idea borrowed from Helios (MIT).
    static func experiment(for habit: ScoreComponent?, goals: Goals) -> String {
        switch habit {
        case .sleep: "Try the same bedtime, \(goals.bedtime.formatted()) ± \(goals.sleepToleranceMinutes) min, every night next week, then compare this review."
        case .meals: "Try meal reminders next week (Settings → Reminders) and see how many meals land in their window."
        case .exercise: "Pick \(goals.workoutsPerWeek) fixed workout days for next week and log each one."
        case .hydration: "Try logging a glass of water with every meal next week."
        case .supplements: "Try taking your vitamins with the same meal every day next week."
        case .movement: "Try one 10-minute walk every day next week."
        case nil: "Keep next week's routine the same. A steady week makes the next review easier to read."
        }
    }
}
