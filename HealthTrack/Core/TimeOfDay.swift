import Foundation

/// A wall-clock time (hour:minute) with no date or time zone attached.
/// Targets like bedtime and meal windows use this so they survive DST and travel.
struct TimeOfDay: Hashable, Comparable, Sendable {
    /// Minutes since midnight, 0..<1440.
    var minutes: Int

    init(_ hour: Int, _ minute: Int = 0) {
        minutes = ((hour * 60 + minute) % 1440 + 1440) % 1440
    }

    /// The local wall-clock time of `date` in `calendar`'s time zone.
    init(of date: Date, in calendar: Calendar) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(c.hour ?? 0, c.minute ?? 0)
    }

    var hour: Int { minutes / 60 }
    var minute: Int { minutes % 60 }

    static func < (a: TimeOfDay, b: TimeOfDay) -> Bool { a.minutes < b.minutes }

    /// Shortest signed distance around the clock, in minutes (-720...720).
    /// 23:50 → 00:10 is +20, not -1420.
    func signedMinutes(to other: TimeOfDay) -> Int {
        var d = (other.minutes - minutes) % 1440
        if d > 720 { d -= 1440 } else if d < -720 { d += 1440 }
        return d
    }

    /// This time on `day`. Calendar resolves DST gaps (a skipped 02:30 becomes the next valid time).
    func on(_ day: Date, in calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            ?? calendar.startOfDay(for: day).addingTimeInterval(TimeInterval(minutes * 60))
    }

    func formatted(locale: Locale = .current) -> String {
        let utc = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = utc
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: Date(timeIntervalSinceReferenceDate: TimeInterval(minutes * 60)))
    }
}

/// Encoded as "HH:mm" so backups stay human-readable.
extension TimeOfDay: Codable {
    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expected HH:mm, got \(s)"))
        }
        self.init(parts[0], parts[1])
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(String(format: "%02d:%02d", hour, minute))
    }
}

extension Array where Element == Double {
    var mean: Double? { isEmpty ? nil : reduce(0, +) / Double(count) }
}
