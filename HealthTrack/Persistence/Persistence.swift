import Foundation
import SwiftData

enum Persistence {
    /// Fixed location: every future version must find the same file.
    static var storeURL: URL { URL.applicationSupportDirectory.appending(path: "HealthTrack.store") }

    static func makeContainer(inMemory: Bool = false, url: URL = storeURL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            config = ModelConfiguration(schema: schema, url: url)
        }
        return try ModelContainer(for: schema, migrationPlan: HealthTrackMigrationPlan.self, configurations: config)
    }
}

/// Logging actions. Views call these; they never build models themselves.
@MainActor
extension ModelContext {
    func settings() -> AppSettings {
        if let existing = try? fetch(FetchDescriptor<AppSettings>()).first { return existing }
        let s = AppSettings()
        insert(s)
        return s
    }

    // MARK: Water

    /// nil when the amount is out of range or it's an accidental double-tap.
    @discardableResult
    func logWater(_ ml: Int, at timestamp: Date = .now, now: Date = .now) -> WaterEntry? {
        guard Hydration.validRangeML.contains(ml) else { return nil }
        var latest = FetchDescriptor<WaterEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        latest.fetchLimit = 1
        let previous = try? fetch(latest).first
        guard !Hydration.isDuplicateTap(previousML: previous?.amountML, previousAt: previous?.createdAt, amountML: ml, at: now) else { return nil }
        let entry = WaterEntry(amountML: ml, at: timestamp, createdAt: now)
        insert(entry)
        return entry
    }

    func water(from start: Date, to end: Date) -> [WaterEntry] {
        let d = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
                                            sortBy: [SortDescriptor(\.timestamp)])
        return (try? fetch(d)) ?? []
    }

    // MARK: Meals

    @discardableResult
    func logMeal(_ type: MealType, foods: [ParsedFood] = [], at timestamp: Date = .now,
                 notes: String = "", calendar: Calendar = .current) -> Meal {
        let meal = Meal(type: type, at: timestamp, calendar: calendar)
        meal.notes = notes
        insert(meal)
        for (i, food) in foods.enumerated() {
            let entry = FoodEntry(name: food.name, grams: food.grams)
            entry.position = i
            insert(entry)
            entry.meal = meal
        }
        return meal
    }

    func meals(from startKey: String, through endKey: String) -> [Meal] {
        let d = FetchDescriptor<Meal>(predicate: #Predicate { $0.day >= startKey && $0.day <= endKey },
                                      sortBy: [SortDescriptor(\.timestamp)])
        return (try? fetch(d)) ?? []
    }

    func meals(onDay key: String) -> [Meal] { meals(from: key, through: key) }

    /// "Same as last time": copies the foods into a new meal.
    @discardableResult
    func duplicate(_ meal: Meal, at timestamp: Date = .now, calendar: Calendar = .current) -> Meal {
        logMeal(meal.mealType, foods: meal.sortedFoods.map { ParsedFood(name: $0.foodName, grams: $0.grams) },
                at: timestamp, calendar: calendar)
    }

    @discardableResult
    func logSavedMeal(_ saved: SavedMeal, at timestamp: Date = .now, calendar: Calendar = .current) -> Meal {
        logMeal(saved.mealType, foods: saved.foods, at: timestamp, calendar: calendar)
    }

    @discardableResult
    func saveAsUsual(_ meal: Meal, name: String) -> SavedMeal {
        let lines = meal.sortedFoods.map { ParsedFood(name: $0.foodName, grams: $0.grams).line }.joined(separator: "\n")
        let saved = SavedMeal(name: name, type: meal.mealType, foodLines: lines)
        insert(saved)
        return saved
    }

    /// Most recently used distinct food names, newest first.
    func recentFoods(limit: Int = 20) -> [String] {
        var d = FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        d.fetchLimit = 300
        var seen = Set<String>(), names: [String] = []
        for entry in (try? fetch(d)) ?? [] where seen.insert(entry.foodName.lowercased()).inserted {
            names.append(entry.foodName)
            if names.count == limit { break }
        }
        return names
    }

    // MARK: Protein

    /// nil when the amount is out of range or it's an accidental double-tap.
    @discardableResult
    func logProtein(_ grams: Int, label: String = "", at timestamp: Date = .now, now: Date = .now) -> ProteinEntry? {
        guard Protein.validRangeGrams.contains(grams) else { return nil }
        var latest = FetchDescriptor<ProteinEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        latest.fetchLimit = 1
        let previous = try? fetch(latest).first
        guard !Hydration.isDuplicateTap(previousML: previous?.grams, previousAt: previous?.createdAt, amountML: grams, at: now) else { return nil }
        let entry = ProteinEntry(grams: grams, label: label.trimmingCharacters(in: .whitespaces), at: timestamp, createdAt: now)
        insert(entry)
        return entry
    }

    func protein(from start: Date, to end: Date) -> [ProteinEntry] {
        let d = FetchDescriptor<ProteinEntry>(predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
                                              sortBy: [SortDescriptor(\.timestamp)])
        return (try? fetch(d)) ?? []
    }

    // MARK: Gym

    @discardableResult
    func logGym(focus: [BodyPart], exercises: [ParsedExercise], at timestamp: Date = .now,
                notes: String = "", calendar: Calendar = .current) -> GymSession {
        let session = GymSession(at: timestamp, calendar: calendar)
        session.focus = focus
        session.notes = notes
        insert(session)
        replaceExercises(of: session, with: exercises)
        return session
    }

    func replaceExercises(of session: GymSession, with exercises: [ParsedExercise]) {
        for old in session.exercises { delete(old) }
        for (i, e) in exercises.enumerated() {
            let entry = GymExercise(e)
            entry.position = i
            insert(entry)
            entry.session = session
        }
        session.updatedAt = .now
    }

    func gymSessions(from startKey: String, through endKey: String) -> [GymSession] {
        let d = FetchDescriptor<GymSession>(predicate: #Predicate { $0.day >= startKey && $0.day <= endKey },
                                            sortBy: [SortDescriptor(\.timestamp)])
        return (try? fetch(d)) ?? []
    }

    /// The most recent session before `dayKey`, for "repeat last session".
    func lastGymSession(before dayKey: String) -> GymSession? {
        var d = FetchDescriptor<GymSession>(predicate: #Predicate { $0.day < dayKey },
                                            sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        d.fetchLimit = 1
        return try? fetch(d).first
    }

    @discardableResult
    func duplicate(_ session: GymSession, at timestamp: Date = .now, calendar: Calendar = .current) -> GymSession {
        logGym(focus: session.focus, exercises: session.sortedExercises.map(\.parsed), at: timestamp, calendar: calendar)
    }

    /// The last line typed for each recently used exercise, newest first — tap to repeat it.
    func recentExerciseLines(limit: Int = 15) -> [String] {
        var d = FetchDescriptor<GymExercise>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        d.fetchLimit = 300
        var seen = Set<String>(), lines: [String] = []
        for e in (try? fetch(d)) ?? [] where seen.insert(e.name.lowercased()).inserted {
            lines.append(e.parsed.line)
            if lines.count == limit { break }
        }
        return lines
    }

    // MARK: Check-in

    func existingCheckIn(onDay key: String) -> DailyCheckIn? {
        try? fetch(FetchDescriptor<DailyCheckIn>(predicate: #Predicate { $0.day == key })).first
    }

    func checkIn(onDay key: String) -> DailyCheckIn {
        if let existing = existingCheckIn(onDay: key) { return existing }
        let c = DailyCheckIn(day: key)
        insert(c)
        return c
    }

    // MARK: Supplements

    /// Creates a pending log for every dose scheduled from `days` ago through today, and marks
    /// still-pending doses from past days as missed. Idempotent.
    // ponytail: 14-day look-back. Free provisioning stops the app after 7 days, so a longer gap can't happen.
    func syncSupplementLogs(today: Date = .now, days: Int = 14, calendar: Calendar = .current) {
        let supplements = (try? fetch(FetchDescriptor<Supplement>())) ?? []
        for offset in 0...days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = DayKey.of(day, calendar: calendar)
            for supplement in supplements {
                for schedule in supplement.schedules where schedule.rule(isActive: supplement.active).isScheduled(on: day, calendar: calendar) {
                    guard !supplement.logs.contains(where: { $0.day == key && $0.scheduleID == schedule.id }) else { continue }
                    let log = SupplementLog(day: key, scheduleID: schedule.id,
                                            scheduledMinutes: schedule.reminderMinutes ?? schedule.preferredTime?.defaultTime.minutes)
                    insert(log)
                    log.supplement = supplement
                }
            }
        }
        let todayKey = DayKey.of(today, calendar: calendar)
        let pending = SupplementStatus.pending.rawValue
        for log in (try? fetch(FetchDescriptor<SupplementLog>(predicate: #Predicate { $0.statusRaw == pending }))) ?? []
        where log.day < todayKey {
            log.status = .missed
        }
    }

    func supplementLogs(from startKey: String, through endKey: String) -> [SupplementLog] {
        let d = FetchDescriptor<SupplementLog>(predicate: #Predicate { $0.day >= startKey && $0.day <= endKey })
        return ((try? fetch(d)) ?? []).sorted { ($0.scheduledMinutes ?? 0, $0.supplement?.name ?? "") < ($1.scheduledMinutes ?? 0, $1.supplement?.name ?? "") }
    }

    func setStatus(_ status: SupplementStatus, for log: SupplementLog, at date: Date = .now) {
        log.status = status
        log.takenAt = status == .taken ? date : nil
    }

    func markAllTaken(onDay key: String, at date: Date = .now) {
        for log in supplementLogs(from: key, through: key) where log.status == .pending || log.status == .missed {
            setStatus(.taken, for: log, at: date)
        }
    }

    /// Pausing removes today's and future pending doses so they don't turn into "missed".
    func setActive(_ active: Bool, for supplement: Supplement, today: Date = .now, calendar: Calendar = .current) {
        supplement.active = active
        supplement.updatedAt = .now
        guard !active else { return }
        let todayKey = DayKey.of(today, calendar: calendar)
        for log in supplement.logs where log.status == .pending && log.day >= todayKey {
            delete(log)
        }
    }
}
