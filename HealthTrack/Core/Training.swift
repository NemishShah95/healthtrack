import Foundation

// MARK: - Exercise catalogue (what the dropdowns offer)

/// Which numbers make sense for an exercise.
enum ExerciseKind: String, Codable, Sendable {
    case strength, bodyweight, timed, cardio

    var fields: [ExerciseField] {
        switch self {
        case .strength: [.sets, .reps, .weight]
        case .bodyweight: [.sets, .reps]
        case .timed: [.sets, .minutes]
        case .cardio: [.minutes, .distance]
        }
    }
}

enum ExerciseField: String, Codable, CaseIterable, Sendable {
    case sets, reps, weight, minutes, distance

    var title: String {
        switch self {
        case .sets: "Sets"
        case .reps: "Reps"
        case .weight: "Weight"
        case .minutes: "Time"
        case .distance: "Distance"
        }
    }

    /// Dropdown choices. Any value already stored is added so editing never loses it.
    func options(including current: Double? = nil) -> [Double] {
        var base: [Double]
        switch self {
        case .sets: base = (1...10).map(Double.init)
        case .reps: base = (1...30).map(Double.init) + [35, 40, 45, 50, 60, 75, 100]
        case .weight: base = (1...20).map(Double.init) + stride(from: 22.5, through: 300, by: 2.5).map { $0 }
        case .minutes: base = [1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90, 105, 120, 150, 180, 240]
        case .distance: base = stride(from: 0.5, through: 10, by: 0.5).map { $0 } + [12, 15, 21.1, 25, 30, 42.2]
        }
        if let current, !base.contains(current) { base.append(current); base.sort() }
        return base
    }

    func format(_ v: Double) -> String {
        let n = String(format: "%g", v)
        switch self {
        case .sets: return "\(n) set\(v == 1 ? "" : "s")"
        case .reps: return "\(n) rep\(v == 1 ? "" : "s")"
        case .weight: return "\(n) kg"
        case .minutes: return "\(n) min"
        case .distance: return "\(n) km"
        }
    }

    var keyPath: WritableKeyPath<ParsedExercise, Double?> {
        switch self {
        case .sets: \.setsValue
        case .reps: \.repsValue
        case .weight: \.weightKg
        case .minutes: \.minutes
        case .distance: \.distanceKm
        }
    }
}

extension ParsedExercise {
    /// Sets and reps as Doubles, so every field can be edited the same way.
    var setsValue: Double? {
        get { sets.map(Double.init) }
        set { sets = newValue.map { Int($0) } }
    }
    var repsValue: Double? {
        get { reps.map(Double.init) }
        set { reps = newValue.map { Int($0) } }
    }

    /// The fields worth showing: the kind's fields plus anything already filled in.
    var visibleFields: [ExerciseField] {
        let kind = ExerciseCatalog.kind(of: name, sample: self)
        return ExerciseField.allCases.filter { kind.fields.contains($0) || self[keyPath: $0.keyPath] != nil }
    }
}

struct CatalogExercise: Sendable {
    let name: String
    let kind: ExerciseKind
    let part: BodyPart
}

enum ExerciseCatalog {
    static let all: [CatalogExercise] = [
        .init(name: "Bench press", kind: .strength, part: .chest),
        .init(name: "Incline bench press", kind: .strength, part: .chest),
        .init(name: "Chest fly", kind: .strength, part: .chest),
        .init(name: "Push-ups", kind: .bodyweight, part: .chest),
        .init(name: "Dips", kind: .bodyweight, part: .chest),
        .init(name: "Tricep dips", kind: .bodyweight, part: .arms),
        .init(name: "Deadlift", kind: .strength, part: .back),
        .init(name: "Barbell row", kind: .strength, part: .back),
        .init(name: "Lat pulldown", kind: .strength, part: .back),
        .init(name: "Pull-ups", kind: .bodyweight, part: .back),
        .init(name: "Overhead press", kind: .strength, part: .shoulders),
        .init(name: "Shoulder press", kind: .strength, part: .shoulders),
        .init(name: "Lateral raise", kind: .strength, part: .shoulders),
        .init(name: "Bicep curl", kind: .strength, part: .arms),
        .init(name: "Tricep extension", kind: .strength, part: .arms),
        .init(name: "Squat", kind: .strength, part: .legs),
        .init(name: "Leg press", kind: .strength, part: .legs),
        .init(name: "Lunges", kind: .strength, part: .legs),
        .init(name: "Romanian deadlift", kind: .strength, part: .legs),
        .init(name: "Calf raise", kind: .strength, part: .legs),
        .init(name: "Hip thrust", kind: .strength, part: .glutes),
        .init(name: "Glute bridge", kind: .bodyweight, part: .glutes),
        .init(name: "Plank", kind: .timed, part: .core),
        .init(name: "Sit-ups", kind: .bodyweight, part: .core),
        .init(name: "Crunches", kind: .bodyweight, part: .core),
        .init(name: "Burpees", kind: .bodyweight, part: .fullBody),
        .init(name: "Run", kind: .cardio, part: .fullBody),
        .init(name: "Walk", kind: .cardio, part: .fullBody),
        .init(name: "Treadmill", kind: .cardio, part: .fullBody),
        .init(name: "Cycle", kind: .cardio, part: .fullBody),
        .init(name: "Swim", kind: .cardio, part: .fullBody),
        .init(name: "Rowing", kind: .cardio, part: .fullBody),
        .init(name: "Elliptical", kind: .cardio, part: .fullBody),
        .init(name: "Jump rope", kind: .cardio, part: .fullBody),
        .init(name: "Stairs", kind: .cardio, part: .fullBody),
    ]

    static func entry(named name: String) -> CatalogExercise? {
        all.first { $0.name.caseInsensitiveCompare(name.trimmingCharacters(in: .whitespaces)) == .orderedSame }
    }

    /// Catalogue kind; for names typed in the past, a guess from the numbers logged.
    static func kind(of name: String, sample: ParsedExercise? = nil) -> ExerciseKind {
        if let known = entry(named: name) { return known.kind }
        if let sample, sample.isCardio { return .cardio }
        if let sample, sample.weightKg == nil, sample.sets != nil || sample.reps != nil { return .bodyweight }
        return .strength
    }

    /// Catalogue exercises for these body parts first (all of them when none chosen), then the rest.
    static func names(for focus: [BodyPart]) -> [String] {
        let first = focus.isEmpty ? all : all.filter { focus.contains($0.part) }
        return first.map(\.name) + all.filter { e in !first.contains { $0.name == e.name } }.map(\.name)
    }

    /// Starting numbers when an exercise is picked from the list.
    static func starter(_ name: String) -> ParsedExercise {
        switch kind(of: name) {
        case .strength: ParsedExercise(name: name, sets: 3, reps: 10)
        case .bodyweight: ParsedExercise(name: name, sets: 3, reps: 10)
        case .timed: ParsedExercise(name: name, sets: 3, minutes: 1)
        case .cardio: ParsedExercise(name: name, minutes: 30)
        }
    }
}

// MARK: - Training goals

/// "Run 5 km, 3× a week" or "Push-ups 3×15, once". Stored inside `Goals`, so it needs no database change
/// and is part of every backup. A goal is met by a logged gym-journal exercise with the same name.
struct TrainingGoal: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    /// Only the target fields are set, e.g. distanceKm 5, or sets 3 + reps 15. `name` is the exercise.
    var target: ParsedExercise
    /// 0 = a one-off milestone.
    var timesPerWeek: Int
    var createdAt = Date()

    var exercise: String { target.name }
    var title: String { target.summary.isEmpty ? target.name : "\(target.name) · \(target.summary)" }
    var isMilestone: Bool { timesPerWeek == 0 }
    var cadenceText: String { isMilestone ? "Milestone" : "\(timesPerWeek)× a week" }

    /// How close one logged exercise gets: the weakest target field, capped at 1. 0 for a different exercise.
    func progress(of e: ParsedExercise) -> Double {
        guard e.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(exercise.trimmingCharacters(in: .whitespaces)) == .orderedSame
        else { return 0 }
        let ratios = ExerciseField.allCases.compactMap { f -> Double? in
            guard let want = target[keyPath: f.keyPath], want > 0 else { return nil }
            return (e[keyPath: f.keyPath] ?? 0) / want
        }
        return min(1, ratios.min() ?? 1)   // no numbers set: doing it at all counts
    }

    func isMet(by e: ParsedExercise) -> Bool { progress(of: e) >= 1 }
}

/// Where a goal stands, from the gym journal.
struct GoalProgress: Equatable, Sendable {
    /// Days this week with an exercise that met the goal.
    var doneThisWeek: Int
    /// Oldest first, current week last: did each of the last weeks reach `timesPerWeek`?
    var recentWeeks: [Bool]
    /// Consecutive weeks met, counting back from the current one (the current week only if already met).
    var streak: Int
    /// Milestones: the first day it was met.
    var achievedOn: Date?
    /// Best single attempt so far, 0…1.
    var best: Double

    /// Ring value: this week for weekly goals, best attempt for milestones.
    func fraction(for goal: TrainingGoal) -> Double {
        goal.isMilestone ? (achievedOn != nil ? 1 : best) : min(1, Double(doneThisWeek) / Double(max(goal.timesPerWeek, 1)))
    }

    static func of(_ goal: TrainingGoal, sessions: [(date: Date, exercises: [ParsedExercise])],
                   weeks: Int = 8, now: Date = .now, calendar: Calendar) -> GoalProgress {
        let metDays = Set(sessions.filter { $0.exercises.contains(where: goal.isMet) }.map { calendar.startOfDay(for: $0.date) })
        let best = sessions.flatMap(\.exercises).map(goal.progress).max() ?? 0
        let achieved = metDays.min()

        let thisWeek = WeeklyReview.week(containing: now, calendar: calendar)
        func count(_ week: DateInterval) -> Int { metDays.filter { week.contains($0) && $0 < week.end }.count }
        let history: [Bool] = (0..<weeks).reversed().map { back in
            guard let anchor = calendar.date(byAdding: .weekOfYear, value: -back, to: now) else { return false }
            return count(WeeklyReview.week(containing: anchor, calendar: calendar)) >= max(goal.timesPerWeek, 1)
        }
        let done = count(thisWeek)
        // The current week only joins the streak once it's met; an unfinished week doesn't break it.
        var streak = 0
        for met in (history.last == true ? history : history.dropLast()).reversed() {
            guard met else { break }
            streak += 1
        }
        return GoalProgress(doneThisWeek: done, recentWeeks: history, streak: streak, achievedOn: achieved, best: best)
    }
}
