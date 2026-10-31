import Foundation

/// Behaviour consistency: "Did I do what I intended to do?"
/// Physiology (HRV, resting HR, sleep stages) is deliberately NOT part of this score.
enum ScoreComponent: String, Codable, CaseIterable, CodingKeyRepresentable, Sendable {
    case sleep, meals, exercise, hydration, supplements, movement

    var title: String {
        switch self {
        case .sleep: "Sleep routine"
        case .meals: "Meal routine"
        case .exercise: "Exercise"
        case .hydration: "Hydration"
        case .supplements: "Supplements"
        case .movement: "Daily movement"
        }
    }

    static let defaultWeights: [ScoreComponent: Double] = [
        .sleep: 25, .meals: 20, .exercise: 20, .hydration: 15, .supplements: 10, .movement: 10,
    ]
}

/// One day reduced to plain values. nil means "no data", which is not the same as zero.
struct DayFacts: Sendable {
    var bedtime: TimeOfDay?
    var wakeTime: TimeOfDay?
    var asleepMinutes: Double?
    var mealTimings: [MealType: MealTiming] = [:]
    /// nil before you started tracking; 0 means tracked but nothing drunk.
    var waterML: Int?
    var supplementStatuses: [SupplementStatus] = []
    var steps: Int?
    var workoutsInLast7Days: Int?
}

enum BehaviorScore {
    /// Each component is 0…1. Formulas are documented in ARCHITECTURE.md.
    static func components(_ f: DayFacts, goals: Goals) -> [ScoreComponent: Double] {
        var c: [ScoreComponent: Double] = [:]
        if let bed = f.bedtime, let wake = f.wakeTime, let asleep = f.asleepMinutes {
            let hits = [goals.isBedtimeOnTarget(bed), goals.isWakeOnTarget(wake), asleep >= Double(goals.sleepTargetMinutes)]
            c[.sleep] = Double(hits.filter { $0 }.count) / Double(hits.count)
        }
        c[.meals] = MealRoutine.consistency(f.mealTimings.values)
        // Rolling 7 days so rest days aren't punished.
        c[.exercise] = f.workoutsInLast7Days.flatMap { ratio($0, goals.workoutsPerWeek) }
        c[.hydration] = f.waterML.flatMap { ratio($0, goals.waterTargetML) }
        c[.supplements] = SupplementAdherence.rate(f.supplementStatuses)
        c[.movement] = f.steps.flatMap { ratio($0, goals.stepTarget) }
        return c
    }

    /// Weighted mean of the components present, 0…1. Missing components are left out and the
    /// remaining weights renormalised, so missing data never counts as failure. nil if nothing is present.
    static func score(_ components: [ScoreComponent: Double],
                      weights: [ScoreComponent: Double] = ScoreComponent.defaultWeights) -> Double? {
        var total = 0.0, weightSum = 0.0
        for (component, value) in components {
            let w = weights[component] ?? 0
            total += w * min(max(value, 0), 1)
            weightSum += w
        }
        return weightSum > 0 ? total / weightSum : nil
    }

    static func ratio(_ value: Int, _ target: Int) -> Double? {
        target > 0 ? min(1, Double(value) / Double(target)) : nil
    }
}
