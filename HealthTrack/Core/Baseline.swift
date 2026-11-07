import Foundation

/// Your usual range for a marker: the middle value of recent days with a band around it
/// (median ± 1.4826 × MAD, about one standard deviation, but not thrown off by one odd night).
/// Needs a minimum number of days before saying anything. Idea borrowed from Helios (MIT).
struct UsualRange: Equatable, Sendable {
    static let minDays = 7
    static let windowDays = 30

    enum Position: Equatable, Sendable { case below, within, above }

    var median: Double
    var low: Double
    var high: Double
    var days: Int

    init?(_ values: [Double], minDays: Int = UsualRange.minDays) {
        guard values.count >= max(minDays, 1), let m = values.median,
              let mad = values.map({ abs($0 - m) }).median else { return nil }
        // ponytail: floor at 3% of the median, so a run of identical days doesn't flag every tiny change.
        let spread = max(1.4826 * mad, 0.03 * abs(m))
        median = m
        low = m - spread
        high = m + spread
        days = values.count
    }

    func position(of value: Double) -> Position { value < low ? .below : value > high ? .above : .within }

    /// "HRV is within your usual range (45–58 ms)."
    func sentence(_ name: String, value: Double, unit: String) -> String {
        let range = "\(Int(low.rounded()))–\(Int(high.rounded())) \(unit)"
        switch position(of: value) {
        case .within: return "\(name) is within your usual range (\(range))."
        case .above: return "\(name) is above your usual range (\(range))."
        case .below: return "\(name) is below your usual range (\(range))."
        }
    }

    /// The `windowDays` days strictly before `key`, so a day never moves its own baseline.
    static func before(_ key: String, in values: [String: Double], calendar: Calendar) -> UsualRange? {
        guard let day = DayKey.date(key, calendar: calendar),
              let start = calendar.date(byAdding: .day, value: -windowDays, to: day) else { return nil }
        let startKey = DayKey.of(start, calendar: calendar)
        return UsualRange(values.filter { $0.key >= startKey && $0.key < key }.map(\.value))
    }
}

extension Array where Element == Double {
    var median: Double? {
        guard !isEmpty else { return nil }
        let s = sorted(), mid = s.count / 2
        return s.count.isMultiple(of: 2) ? (s[mid - 1] + s[mid]) / 2 : s[mid]
    }
}

/// Is the watch still writing to Apple Health? Sleep and HRV only come from the watch
/// (the iPhone counts steps itself), so they're what we check. Idea borrowed from Helios (MIT).
enum DataFreshness {
    /// True when the newest watch data is older than yesterday. nil latest = never had any: Settings covers that.
    static func isStale(latestWatchDay: String?, now: Date, calendar: Calendar) -> Bool {
        guard let latest = latestWatchDay,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else { return false }
        return latest < DayKey.of(yesterday, calendar: calendar)
    }

    /// "No watch data since Tue 3 Nov. Open Zepp to sync, then pull down to refresh."
    static func message(latestWatchDay: String, calendar: Calendar, locale: Locale = .current) -> String {
        let day = DayKey.date(latestWatchDay, calendar: calendar)
            .map { $0.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated).day().month(.abbreviated)) }
            ?? latestWatchDay
        return "No watch data since \(day). Open Zepp to sync, then pull down to refresh."
    }
}
