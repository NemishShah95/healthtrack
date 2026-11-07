import Foundation

enum BodyPart: String, Codable, CaseIterable, Sendable {
    case chest, back, shoulders, arms, legs, glutes, core, fullBody

    var title: String { self == .fullBody ? "Full body" : rawValue.capitalized }
}

/// One exercise from a typed line: "Bench press 3x10 60 kg", "Treadmill 20 min 3 km".
struct ParsedExercise: Codable, Equatable, Sendable {
    var name: String
    var sets: Int?
    var reps: Int?
    var weightKg: Double?
    var minutes: Double?
    var distanceKm: Double?

    var isCardio: Bool { (minutes != nil || distanceKm != nil) && sets == nil && reps == nil && weightKg == nil }

    /// Sets × reps × weight, when all three are known.
    var volumeKg: Double? {
        guard let sets, let reps, let weightKg else { return nil }
        return Double(sets * reps) * weightKg
    }

    /// The inverse of `GymLog.parse`, so sessions can be edited as text.
    var line: String {
        func n(_ v: Double) -> String { String(format: "%g", v) }
        var parts = [name]
        if let sets, let reps { parts.append("\(sets)x\(reps)") } else if let sets { parts.append("\(sets) sets") } else if let reps { parts.append("\(reps) reps") }
        if let weightKg { parts.append("\(n(weightKg)) kg") }
        if let minutes { parts.append("\(n(minutes)) min") }
        if let distanceKm { parts.append("\(n(distanceKm)) km") }
        return parts.joined(separator: " ")
    }

    /// "3x10 · 60 kg" — the numbers without the name.
    var summary: String {
        var parts: [String] = []
        if let sets, let reps { parts.append("\(sets)×\(reps)") } else if let sets { parts.append("\(sets) sets") } else if let reps { parts.append("\(reps) reps") }
        if let weightKg { parts.append("\(String(format: "%g", weightKg)) kg") }
        if let minutes { parts.append("\(String(format: "%g", minutes)) min") }
        if let distanceKm { parts.append("\(String(format: "%g", distanceKm)) km") }
        return parts.joined(separator: " · ")
    }
}

enum GymLog {
    /// One exercise per line. Pounds and miles are converted to kg and km.
    static func parse(_ text: String) -> [ParsedExercise] {
        text.split(whereSeparator: \.isNewline).compactMap { parseLine(String($0)) }
    }

    static func parseLine(_ raw: String) -> ParsedExercise? {
        let edges = CharacterSet(charactersIn: "-–•*:@, ").union(.whitespaces)
        var line = raw.trimmingCharacters(in: edges)
        guard !line.isEmpty else { return nil }
        var e = ParsedExercise(name: "")

        func take(_ regex: Regex<(Substring, Substring)>) -> Double? {
            guard let m = line.firstMatch(of: regex), let v = Double(m.1) else { return nil }
            line.removeSubrange(m.range)
            return v
        }

        if let m = line.firstMatch(of: #/(\d+)\s*[x×*]\s*(\d+)/#.ignoresCase()) {
            e.sets = Int(m.1)
            e.reps = Int(m.2)
            line.removeSubrange(m.range)
        }
        if e.sets == nil, let v = take(#/(\d+)\s*sets?\b/#.ignoresCase()) { e.sets = Int(v) }
        if e.reps == nil, let v = take(#/(\d+)\s*reps?\b/#.ignoresCase()) { e.reps = Int(v) }
        if let v = take(#/(\d+(?:\.\d+)?)\s*kgs?\b/#.ignoresCase()) {
            e.weightKg = v
        } else if let v = take(#/(\d+(?:\.\d+)?)\s*lbs?\b/#.ignoresCase()) {
            e.weightKg = (v * 0.45359237 * 10).rounded() / 10
        }
        if let v = take(#/(\d+(?:\.\d+)?)\s*(?:min|mins|minutes?)\b/#.ignoresCase()) { e.minutes = v }
        if let v = take(#/(\d+(?:\.\d+)?)\s*(?:km|k)\b/#.ignoresCase()) {
            e.distanceKm = v
        } else if let v = take(#/(\d+(?:\.\d+)?)\s*(?:mi|miles?)\b/#.ignoresCase()) {
            e.distanceKm = (v * 1.609344 * 100).rounded() / 100
        }

        let name = line.split(whereSeparator: \.isWhitespace).joined(separator: " ").trimmingCharacters(in: edges)
        e.name = name.isEmpty ? "Exercise" : name
        return e
    }
}

enum Protein {
    static let quickAddGrams = [10, 20, 30]
    static let validRangeGrams = 1...300
    /// The "other amount" dropdown.
    static let pickerGrams = Array(stride(from: 5, through: 100, by: 5)) + [120, 150]
    static let commonSources = ["Whey shake", "Eggs", "Chicken", "Paneer", "Greek yogurt", "Dal / lentils",
                                "Tofu", "Fish", "Milk", "Protein bar"]
}
