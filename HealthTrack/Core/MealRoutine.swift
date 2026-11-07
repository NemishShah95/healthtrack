import Foundation

enum MealType: String, Codable, CaseIterable, CodingKeyRepresentable, Sendable {
    case breakfast, lunch, dinner, snack, custom
    /// Meals that have a target window and count toward meal consistency.
    static let targeted: [MealType] = [.breakfast, .lunch, .dinner]
}

/// Target window for a meal, e.g. breakfast 07:30–09:30.
struct MealWindow: Codable, Hashable, Sendable {
    // ponytail: windows can't cross midnight; add wrap-around if a window ever needs to.
    var start: TimeOfDay
    var end: TimeOfDay

    func contains(_ t: TimeOfDay) -> Bool { start <= t && t <= end }

    static let defaults: [MealType: MealWindow] = [
        .breakfast: .init(start: .init(7, 30), end: .init(9, 30)),
        .lunch: .init(start: .init(12), end: .init(14)),
        .dinner: .init(start: .init(19), end: .init(21)),
    ]
}

enum MealTiming: String, Codable, Sendable {
    case onTime, early, late, skipped, pending

    var isLogged: Bool { self == .onTime || self == .early || self == .late }

    /// Contribution to meal consistency. Eating the meal at all is the habit; timing is the refinement,
    /// so an off-window meal earns half. Pending meals aren't judged yet.
    var points: Double? {
        switch self {
        case .onTime: 1
        case .early, .late: 0.5
        case .skipped: 0
        case .pending: nil
        }
    }
}

struct ParsedFood: Codable, Equatable, Sendable {
    var name: String
    var grams: Double?

    /// "oats 80 g". The inverse of `MealRoutine.parseFoods`, so saved meals can be stored as plain text.
    var line: String { grams.map { "\(name) \(String(format: "%g", $0)) g" } ?? name }
}

enum MealRoutine {
    /// - Parameters:
    ///   - loggedTimes: local times of this meal type logged that day (in the time zone where each was logged).
    ///   - now: the current local time when judging today; nil for a finished day.
    static func timing(loggedTimes: [TimeOfDay], window: MealWindow, now: TimeOfDay?) -> MealTiming {
        if loggedTimes.contains(where: window.contains) { return .onTime }
        guard let first = loggedTimes.min() else {
            if let now, now <= window.end { return .pending }
            return .skipped
        }
        return first < window.start ? .early : .late
    }

    /// The meal a one-tap "log" button should mean: the latest window that has started and isn't
    /// logged yet, otherwise the next one coming up. nil when all three are logged.
    static func nextMeal(logged: Set<MealType>, windows: [MealType: MealWindow], now: TimeOfDay) -> MealType? {
        let open = MealType.targeted.filter { !logged.contains($0) }.compactMap { t in windows[t].map { (type: t, window: $0) } }
        return open.filter { $0.window.start <= now }.max { $0.window.start < $1.window.start }?.type
            ?? open.min { $0.window.start < $1.window.start }?.type
    }

    /// Mean points over the meals that can be judged; nil when none can be yet.
    static func consistency(_ timings: some Collection<MealTiming>) -> Double? {
        timings.compactMap(\.points).mean
    }

    /// Zero, negative or non-numeric grams mean "no quantity given" rather than an error,
    /// so a typo never blocks logging a meal.
    /// The grams dropdown.
    static let gramOptions: [Double] = [10, 20, 25, 30, 40, 50, 60, 75, 80, 100, 120, 150, 175, 200, 250, 300, 350, 400, 500]
    /// Offered in the food dropdown after your favourites and recent foods.
    static let commonFoods = ["Oats", "Eggs", "Banana", "Apple", "Yogurt", "Milk", "Bread", "Rice", "Roti", "Dal",
                              "Chicken", "Fish", "Paneer", "Tofu", "Salad", "Vegetables", "Pasta", "Poha", "Fruit", "Nuts",
                              "Smoothie", "Coffee", "Tea"]

    static func cleanGrams(_ grams: Double?) -> Double? {
        guard let grams, grams.isFinite, grams > 0 else { return nil }
        return grams
    }

    /// One food per line or comma: "oats 80 g", "- banana", "yogurt 180g".
    /// A trailing "<number> g" becomes grams; anything else is just a name.
    static func parseFoods(_ text: String) -> [ParsedFood] {
        let withGrams = #/(.*?\D)\s*(\d+(?:\.\d+)?)\s*(?:g|gr|grams?)/#.ignoresCase()
        return text.split(whereSeparator: { $0.isNewline || $0 == "," }).compactMap { raw in
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: "-•* ").union(.whitespaces))
            guard !line.isEmpty else { return nil }
            if let m = line.wholeMatch(of: withGrams) {
                let name = m.1.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return ParsedFood(name: name, grams: cleanGrams(Double(m.2))) }
            }
            return ParsedFood(name: line, grams: nil)
        }
    }
}
