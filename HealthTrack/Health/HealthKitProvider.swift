import Foundation
import HealthKit

/// Reads Apple Health on the iPhone. Read-only: HealthTrack never writes to Health.
final class HealthKitProvider: HealthDataProvider, @unchecked Sendable {
    private let store = HKHealthStore()

    /// Only what the app displays. Each identifier exists in the iOS 17 SDK.
    static let readTypes: Set<HKObjectType> = [
        HKCategoryType(.sleepAnalysis),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKObjectType.workoutType(),
    ]

    func accessState() async -> HealthAccess {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: Self.readTypes)
        return status == .shouldRequest ? .notRequested : .requested
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func snapshot(from start: Date, to end: Date, calendar: Calendar) async -> HealthSnapshot {
        guard HKHealthStore.isHealthDataAvailable() else { return HealthSnapshot() }
        let perMinute = HKUnit.count().unitDivided(by: .minute())
        async let sleep = sleepSamples(from: start, to: end)
        async let steps = daily(.stepCount, .count(), .cumulativeSum, start, end, calendar)
        async let hrv = daily(.heartRateVariabilitySDNN, .secondUnit(with: .milli), .discreteAverage, start, end, calendar)
        async let resting = daily(.restingHeartRate, perMinute, .discreteAverage, start, end, calendar)
        async let energy = daily(.activeEnergyBurned, .kilocalorie(), .cumulativeSum, start, end, calendar)
        async let workouts = workouts(from: start, to: end)
        return await HealthSnapshot(sleepSamples: sleep, steps: steps.mapValues { Int($0.rounded()) }, hrv: hrv,
                                    restingHR: resting, activeEnergy: energy, workouts: workouts)
    }

    private func sleepSamples(from start: Date, to end: Date) async -> [SleepSample] {
        // Start a day early so a night that began the previous evening is complete.
        let predicate = HKQuery.predicateForSamples(withStart: start.addingTimeInterval(-86_400), end: end)
        let query = HKSampleQueryDescriptor(predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
                                            sortDescriptors: [SortDescriptor(\.startDate)])
        let samples = (try? await query.result(for: store)) ?? []
        return samples.compactMap { s in
            Self.stage(s.value).map {
                SleepSample(start: s.startDate, end: s.endDate, stage: $0, source: s.sourceRevision.source.bundleIdentifier)
            }
        }
    }

    static func stage(_ value: Int) -> SleepStage? {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed: .inBed
        case .awake: .awake
        case .asleepCore: .core
        case .asleepDeep: .deep
        case .asleepREM: .rem
        case .asleepUnspecified: .asleepUnspecified
        default: nil   // unknown future values are ignored rather than guessed
        }
    }

    /// One value per local day. Health merges overlapping sources (watch + phone) the same way the Health app does.
    private func daily(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ options: HKStatisticsOptions,
                       _ start: Date, _ end: Date, _ calendar: Calendar) async -> [String: Double] {
        let type = HKQuantityType(id)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: options, anchorDate: calendar.startOfDay(for: start), intervalComponents: DateComponents(day: 1))
        guard let collection = try? await query.result(for: store) else { return [:] }
        var values: [String: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            let quantity = options.contains(.cumulativeSum) ? stats.sumQuantity() : stats.averageQuantity()
            if let v = quantity?.doubleValue(for: unit) { values[DayKey.of(stats.startDate, calendar: calendar)] = v }
        }
        return values
    }

    private func workouts(from start: Date, to end: Date) async -> [WorkoutSummary] {
        let query = HKSampleQueryDescriptor(predicates: [.workout(HKQuery.predicateForSamples(withStart: start, end: end))],
                                            sortDescriptors: [SortDescriptor(\.startDate)])
        let workouts = (try? await query.result(for: store)) ?? []
        return workouts.map {
            WorkoutSummary(start: $0.startDate, end: $0.endDate, activityName: Self.name(of: $0.workoutActivityType),
                           activeEnergyKcal: $0.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()))
        }
    }

    static func name(of type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Running"
        case .walking: "Walking"
        case .hiking: "Hiking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Strength Training"
        case .highIntensityIntervalTraining: "HIIT"
        case .coreTraining: "Core Training"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .mixedCardio: "Cardio"
        case .socialDance, .cardioDance: "Dance"
        case .badminton: "Badminton"
        case .tennis: "Tennis"
        case .cricket: "Cricket"
        default: "Workout"
        }
    }
}
