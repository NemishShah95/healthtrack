import Foundation

enum TrendDirection: String, Sendable {
    case up, down, stable

    var arrow: String {
        switch self {
        case .up: "↑"
        case .down: "↓"
        case .stable: "→"
        }
    }
}

enum Trend {
    /// Relative change between the means of two periods. nil if either has fewer than `minSamples` values.
    static func percentChange(current: [Double], previous: [Double], minSamples: Int = 3) -> Double? {
        guard current.count >= minSamples, previous.count >= minSamples,
              let c = current.mean, let p = previous.mean, p != 0 else { return nil }
        return (c - p) / abs(p)
    }

    /// Changes within ±`threshold` (default 5%) are "stable".
    static func direction(current: [Double], previous: [Double], threshold: Double = 0.05, minSamples: Int = 3) -> TrendDirection? {
        guard let change = percentChange(current: current, previous: previous, minSamples: minSamples) else { return nil }
        return change > threshold ? .up : change < -threshold ? .down : .stable
    }
}

/// Descriptive observations only — associations, never causes, never diagnosis.
/// Each one needs a minimum sample before it's shown. Methodology: ARCHITECTURE.md → Insights.
struct Insight: Equatable, Sendable {
    var text: String
    var sampleSize: Int
}

enum Insights {
    static let minGroup = 5      // per group, for "nights when X vs not X"
    static let minPeriod = 14    // per period, for period-over-period changes
    static let minDays = 7       // for rate statements
    static let minSleepDifferenceMinutes = 10

    /// Generated text must never contain these (enforced by tests).
    static let bannedPhrases = ["because", "caused", "causes", "leads to", "improve", "results in", "due to", "diagnos"]

    static func sleepVsDinnerTime(_ nights: [(dinner: TimeOfDay, asleepMinutes: Double)],
                                  cutoff: TimeOfDay = .init(20, 30), locale: Locale = .current) -> Insight? {
        let early = nights.filter { $0.dinner < cutoff }.map(\.asleepMinutes)
        let late = nights.filter { $0.dinner >= cutoff }.map(\.asleepMinutes)
        guard early.count >= minGroup, late.count >= minGroup, let e = early.mean, let l = late.mean else { return nil }
        let diff = Int((e - l).rounded())
        guard abs(diff) >= minSleepDifferenceMinutes else { return nil }
        return Insight(
            text: "Your average sleep was \(abs(diff)) minutes \(diff > 0 ? "longer" : "shorter") on nights when dinner was before \(cutoff.formatted(locale: locale)).",
            sampleSize: nights.count)
    }

    static func hrvChange(last30: [Double], prior30: [Double]) -> Insight? {
        guard let change = Trend.percentChange(current: last30, previous: prior30, minSamples: minPeriod) else { return nil }
        let pct = Int((change * 100).rounded())
        let text = pct == 0
            ? "Your 30-day HRV average is about the same as the prior 30 days."
            : "Your 30-day HRV average is \(abs(pct))% \(pct > 0 ? "above" : "below") the prior 30 days."
        return Insight(text: text, sampleSize: last30.count + prior30.count)
    }

    static func bedtimeTargetRate(hits: Int, nights: Int, period: String = "this month") -> Insight? {
        guard nights >= minDays else { return nil }
        let pct = Int((Double(hits) / Double(nights) * 100).rounded())
        return Insight(text: "You met your bedtime target on \(pct)% of nights \(period).", sampleSize: nights)
    }

    static func supplementLogged(name: String, taken: Int, scheduled: Int) -> Insight? {
        guard scheduled >= minDays else { return nil }
        return Insight(text: "\(name) was logged on \(taken) of \(scheduled) scheduled days.", sampleSize: scheduled)
    }
}
