import Foundation

/// Mirrors HKCategoryValueSleepAnalysis. Stages are wearable estimates, not measurements.
enum SleepStage: String, Codable, Sendable {
    case inBed, awake, core, deep, rem, asleepUnspecified

    var isAsleep: Bool { self == .core || self == .deep || self == .rem || self == .asleepUnspecified }
}

/// Plain copy of a HealthKit sleep sample, so aggregation is testable without HealthKit.
struct SleepSample: Equatable, Sendable {
    var start: Date
    var end: Date
    var stage: SleepStage
    /// Source bundle identifier (Zepp, iPhone, …).
    var source: String

    var interval: DateInterval { DateInterval(start: start, end: max(start, end)) }
}

/// One night's main sleep. `night` is the start of the day you woke up on.
struct NightSummary: Equatable, Sendable {
    var night: Date
    var sleepStart: Date
    var finalWake: Date
    var asleep: TimeInterval
    var inBed: TimeInterval
    var awake: TimeInterval
    var interruptions: Int
    /// nil when the source wrote no stage data (only "asleep").
    var core: TimeInterval?
    var deep: TimeInterval?
    var rem: TimeInterval?
    /// The chosen source's samples for this night, oldest first: what the sleep chart draws.
    var samples: [SleepSample] = []
}

enum SleepAggregator {
    /// Asleep gaps up to this long stay in the same session (a long night-time wake doesn't split the night).
    static let sessionGap: TimeInterval = 90 * 60
    /// Sleep ending at or after this hour belongs to the next day's night.
    static let dayCutoffHour = 18
    /// Gaps between asleep periods shorter than this aren't counted as interruptions.
    static let minInterruption: TimeInterval = 60

    static func nights(from samples: [SleepSample], calendar: Calendar) -> [NightSummary] {
        let valid = samples.filter { $0.end > $0.start }
        let inBed = valid.filter { $0.stage == .inBed }.map(\.interval)

        // Per source, keep only the longest session per night — this drops naps.
        var candidates: [Date: [[SleepSample]]] = [:]
        for (_, group) in Dictionary(grouping: valid.filter(\.stage.isAsleep), by: \.source) {
            var longest: [Date: (asleep: TimeInterval, samples: [SleepSample])] = [:]
            for session in merge(group.map(\.interval), gap: sessionGap) {
                let inSession = group.filter { session.intersects($0.interval) }
                let night = nightDate(wake: session.end, calendar: calendar)
                let asleep = total(inSession.map(\.interval))
                if asleep > longest[night]?.asleep ?? 0 { longest[night] = (asleep, inSession) }
            }
            for (night, best) in longest { candidates[night, default: []].append(best.samples) }
        }

        // ponytail: one source per night (staged data first, then most sleep) instead of merging
        // sources sample by sample. Fine while one watch writes stages; revisit if M19 shows gaps.
        // Never adding sources together is also what prevents double counting.
        return candidates.compactMap { night, sources in
            sources.max { rank($0) < rank($1) }.map { summary(night: night, samples: $0, inBed: inBed) }
        }
        .sorted { $0.night < $1.night }
    }

    static func nightDate(wake: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: wake)
        guard calendar.component(.hour, from: wake) >= dayCutoffHour else { return day }
        return calendar.date(byAdding: .day, value: 1, to: day) ?? day
    }

    /// Merges overlapping intervals, plus any separated by at most `gap` seconds.
    static func merge(_ intervals: [DateInterval], gap: TimeInterval = 0) -> [DateInterval] {
        var out: [DateInterval] = []
        for i in intervals.sorted(by: { $0.start < $1.start }) {
            if let last = out.last, i.start.timeIntervalSince(last.end) <= gap {
                out[out.count - 1] = DateInterval(start: last.start, end: max(last.end, i.end))
            } else {
                out.append(i)
            }
        }
        return out
    }

    /// Duration covered by the intervals, counting overlaps once.
    static func total(_ intervals: [DateInterval]) -> TimeInterval {
        merge(intervals).reduce(0) { $0 + $1.duration }
    }

    private static func isStaged(_ samples: [SleepSample]) -> Bool {
        samples.contains { $0.stage != .asleepUnspecified }
    }

    private static func rank(_ samples: [SleepSample]) -> (Int, TimeInterval) {
        (isStaged(samples) ? 1 : 0, total(samples.map(\.interval)))
    }

    private static func summary(night: Date, samples: [SleepSample], inBed: [DateInterval]) -> NightSummary {
        let parts = merge(samples.map(\.interval))
        let span = DateInterval(start: parts[0].start, end: parts[parts.count - 1].end)
        let asleep = parts.reduce(0) { $0 + $1.duration }
        let staged = isStaged(samples)
        func stage(_ s: SleepStage) -> TimeInterval? {
            staged ? total(samples.filter { $0.stage == s }.map(\.interval)) : nil
        }
        return NightSummary(
            night: night,
            sleepStart: span.start,
            finalWake: span.end,
            asleep: asleep,
            inBed: total([span] + inBed.filter { $0.intersects(span) }),
            // Awake = gaps inside the night. Derived rather than read, since not every source writes awake samples.
            awake: span.duration - asleep,
            interruptions: zip(parts, parts.dropFirst()).filter { pair in
                pair.1.start.timeIntervalSince(pair.0.end) >= minInterruption
            }.count,
            core: stage(.core),
            deep: stage(.deep),
            rem: stage(.rem),
            samples: samples.sorted { $0.start < $1.start }
        )
    }
}
