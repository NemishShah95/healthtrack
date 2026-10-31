import Foundation

struct WorkoutSummary: Equatable, Sendable {
    var start: Date
    var end: Date
    var activityName: String
    var activeEnergyKcal: Double?

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Everything HealthTrack reads from Apple Health for a date range. Daily values are keyed by DayKey.
/// Missing permissions or missing data simply leave collections empty — never an error.
struct HealthSnapshot: Sendable {
    var sleepSamples: [SleepSample] = []
    var steps: [String: Int] = [:]
    var hrv: [String: Double] = [:]          // mean SDNN, ms
    var restingHR: [String: Double] = [:]    // bpm
    var activeEnergy: [String: Double] = [:] // kcal (an estimate)
    var workouts: [WorkoutSummary] = []

    func nights(calendar: Calendar) -> [String: NightSummary] {
        Dictionary(SleepAggregator.nights(from: sleepSamples, calendar: calendar).map { (DayKey.of($0.night, calendar: calendar), $0) },
                   uniquingKeysWith: { a, _ in a })
    }
}

enum HealthAccess: Equatable, Sendable {
    /// Health data isn't available on this device.
    case unavailable
    /// Apple's permission sheet hasn't been shown yet.
    case notRequested
    /// The sheet was shown. Apple never tells apps which read categories were allowed.
    case requested
}

protocol HealthDataProvider: Sendable {
    func accessState() async -> HealthAccess
    /// Shows Apple's permission sheet the first time; later calls do nothing.
    func requestAuthorization() async throws
    func snapshot(from start: Date, to end: Date, calendar: Calendar) async -> HealthSnapshot
}

/// Deterministic fake Health data for the simulator, previews and tests.
/// Choose a scenario with the launch argument `-mockHealth <scenario>`.
struct MockHealthDataProvider: HealthDataProvider {
    enum Scenario: String, CaseIterable, Sendable {
        case full, empty, denied, partial, noStages, unavailable
    }

    var scenario: Scenario = .full
    var historyDays = 90
    var now = Date()

    func accessState() async -> HealthAccess { scenario == .unavailable ? .unavailable : .requested }
    func requestAuthorization() async throws {}

    func snapshot(from start: Date, to end: Date, calendar: Calendar) async -> HealthSnapshot {
        var s = HealthSnapshot()
        guard [.full, .partial, .noStages].contains(scenario),
              let first = calendar.date(byAdding: .day, value: 1 - historyDays, to: calendar.startOfDay(for: now)) else { return s }
        var day = max(calendar.startOfDay(for: start), first)
        while day < end, day <= now {
            // Seeded by the day, so the same day always gets the same data.
            var rng = SplitMix64(seed: UInt64(DayKey.of(day, calendar: calendar).hashValueStable))
            let key = DayKey.of(day, calendar: calendar)
            let index = Double(calendar.dateComponents([.day], from: first, to: day).day ?? 0)

            s.steps[key] = Int.random(in: 3_000...13_500, using: &rng)
            s.activeEnergy[key] = Double.random(in: 250...750, using: &rng)
            if Double.random(in: 0...1, using: &rng) < 0.55 {
                let startAt = TimeOfDay(17, Int.random(in: 30...150, using: &rng)).on(day, in: calendar)
                s.workouts.append(WorkoutSummary(
                    start: startAt, end: startAt.addingTimeInterval(Double(Int.random(in: 25...70, using: &rng)) * 60),
                    activityName: ["Running", "Strength Training", "Walking", "Cycling", "Yoga"].randomElement(using: &rng)!,
                    activeEnergyKcal: Double.random(in: 150...550, using: &rng)))
            }
            if scenario != .partial {
                s.hrv[key] = 46 + index * 0.06 + Double.random(in: -9...9, using: &rng)   // gentle upward trend
                s.restingHR[key] = 59 - index * 0.02 + Double.random(in: -3...3, using: &rng)
                s.sleepSamples += Self.night(wakingOn: day, staged: scenario != .noStages, rng: &rng, calendar: calendar)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return s
    }

    /// One night of samples ending on the morning of `day`, in ~90-minute cycles.
    private static func night(wakingOn day: Date, staged: Bool, rng: inout SplitMix64, calendar: Calendar) -> [SleepSample] {
        guard let evening = calendar.date(byAdding: .day, value: -1, to: day) else { return [] }
        var t = TimeOfDay(22, Int.random(in: 20...110, using: &rng)).on(evening, in: calendar)
        let target = Double(Int.random(in: 360...510, using: &rng)) * 60
        let bedStart = t.addingTimeInterval(-10 * 60)
        guard staged else {
            return [SleepSample(start: t, end: t + target, stage: .asleepUnspecified, source: "mock.watch")]
        }
        var samples: [SleepSample] = [], asleep = 0.0, cycle = 0
        while asleep < target {
            let deep = Double(max(5, 25 - cycle * 6))
            let rem = Double(12 + cycle * 6)
            for (stage, minutes) in [(SleepStage.core, 40.0), (.deep, deep), (.core, 15), (.rem, rem)] {
                let d = min(minutes * 60, target - asleep)
                guard d > 0 else { break }
                samples.append(SleepSample(start: t, end: t + d, stage: stage, source: "mock.watch"))
                t += d
                asleep += d
            }
            if Double.random(in: 0...1, using: &rng) < 0.35 {
                let awake = Double(Int.random(in: 3...12, using: &rng)) * 60
                samples.append(SleepSample(start: t, end: t + awake, stage: .awake, source: "mock.watch"))
                t += awake
            }
            cycle += 1
        }
        samples.append(SleepSample(start: bedStart, end: t + 5 * 60, stage: .inBed, source: "mock.phone"))
        return samples
    }
}

/// Small seeded RNG so mock and sample data are reproducible.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension String {
    /// FNV-1a. Unlike `hashValue`, stable across launches.
    var hashValueStable: UInt64 {
        utf8.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
    }
}
