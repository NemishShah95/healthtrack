import Foundation
import SwiftData

/// Converts the database to and from the versioned backup format in Core/Export.swift.
@MainActor
extension ModelContext {
    func exportBundle(appVersion: String, now: Date = .now) -> ExportBundle {
        func all<T: PersistentModel>(_: T.Type) -> [T] { (try? fetch(FetchDescriptor<T>())) ?? [] }
        let settings = settings()
        // Stable order, so two backups of the same data are identical files.
        var bundle = ExportBundle(
            exportedAt: now,
            appVersion: appVersion,
            goals: settings.goals,
            favoriteFoods: settings.favoriteFoods,
            meals: all(Meal.self).map { m in
                MealRecord(id: m.id, day: m.day, timestamp: m.timestamp, timeZone: m.timeZoneID, mealType: m.mealType,
                           customName: m.customName, notes: m.notes, qualityRating: m.qualityRating,
                           createdAt: m.createdAt, updatedAt: m.updatedAt,
                           foods: m.sortedFoods.map {
                               FoodRecord(id: $0.id, foodName: $0.foodName, grams: $0.grams,
                                          servingDescription: $0.servingDescription, notes: $0.notes, createdAt: $0.createdAt)
                           })
            },
            savedMeals: all(SavedMeal.self).map {
                SavedMealRecord(id: $0.id, name: $0.name, mealType: $0.mealType, foods: $0.foods, createdAt: $0.createdAt)
            },
            water: all(WaterEntry.self).map {
                WaterRecord(id: $0.id, timestamp: $0.timestamp, amountML: $0.amountML, createdAt: $0.createdAt)
            },
            supplements: all(Supplement.self).map { s in
                SupplementRecord(id: s.id, name: s.name, dosageText: s.dosageText, active: s.active, notes: s.notes,
                                 createdAt: s.createdAt, updatedAt: s.updatedAt,
                                 schedules: s.schedules.map {
                                     ScheduleRecord(id: $0.id, daysOfWeek: $0.daysOfWeek.sorted(), preferredTime: $0.preferredTime,
                                                    reminderEnabled: $0.reminderEnabled, reminderTime: $0.reminderTime,
                                                    startDate: $0.startDate, endDate: $0.endDate)
                                 })
            },
            supplementLogs: all(SupplementLog.self).compactMap { log in
                log.supplement.map {
                    SupplementLogRecord(id: log.id, supplementID: $0.id, scheduleID: log.scheduleID, scheduledDay: log.day,
                                        scheduledTime: log.scheduledMinutes.map { TimeOfDay(0, $0) }, status: log.status,
                                        takenAt: log.takenAt, createdAt: log.createdAt)
                }
            },
            checkIns: all(DailyCheckIn.self).map {
                CheckInRecord(id: $0.id, day: $0.day, energy: $0.energy, mood: $0.mood, stress: $0.stress,
                              notes: $0.notes, createdAt: $0.createdAt)
            })
        bundle.gymSessions = all(GymSession.self).map { g in
            GymSessionRecord(id: g.id, day: g.day, timestamp: g.timestamp, focus: g.focus, notes: g.notes,
                             createdAt: g.createdAt, updatedAt: g.updatedAt,
                             exercises: g.sortedExercises.map { GymExerciseRecord(id: $0.id, exercise: $0.parsed, createdAt: $0.createdAt) })
        }.sorted { ($0.timestamp, $0.id.uuidString) < ($1.timestamp, $1.id.uuidString) }
        bundle.protein = all(ProteinEntry.self).map {
            ProteinRecord(id: $0.id, timestamp: $0.timestamp, grams: $0.grams, label: $0.label, createdAt: $0.createdAt)
        }.sorted { ($0.timestamp, $0.id.uuidString) < ($1.timestamp, $1.id.uuidString) }
        bundle.meals.sort { ($0.timestamp, $0.id.uuidString) < ($1.timestamp, $1.id.uuidString) }
        bundle.savedMeals.sort { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        bundle.water.sort { ($0.timestamp, $0.id.uuidString) < ($1.timestamp, $1.id.uuidString) }
        bundle.supplements.sort { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        bundle.supplementLogs.sort { ($0.scheduledDay, $0.supplementID.uuidString, $0.id.uuidString) < ($1.scheduledDay, $1.supplementID.uuidString, $1.id.uuidString) }
        bundle.checkIns.sort { ($0.day, $0.id.uuidString) < ($1.day, $1.id.uuidString) }
        return bundle
    }

    /// Restores a backup. Records whose ID already exists are skipped, so importing the same
    /// file twice never duplicates anything. Goals are replaced; favourite foods are merged.
    /// Returns the number of records added.
    @discardableResult
    func importBundle(_ b: ExportBundle) throws -> Int {
        func ids<T: PersistentModel>(_: T.Type, _ id: (T) -> UUID) -> Set<UUID> {
            Set(((try? fetch(FetchDescriptor<T>())) ?? []).map(id))
        }
        var added = 0

        let settings = settings()
        settings.goals = b.goals
        settings.favoriteFoods = Array(Set(settings.favoriteFoods).union(b.favoriteFoods)).sorted()

        let mealIDs = ids(Meal.self, \.id)
        for r in b.meals where !mealIDs.contains(r.id) {
            let m = Meal(type: r.mealType, at: r.timestamp, calendar: .current)
            m.id = r.id; m.day = r.day; m.timeZoneID = r.timeZone; m.customName = r.customName; m.notes = r.notes
            m.qualityRating = r.qualityRating; m.createdAt = r.createdAt; m.updatedAt = r.updatedAt
            insert(m)
            for (i, f) in r.foods.enumerated() {
                let e = FoodEntry(name: f.foodName, grams: f.grams)
                e.id = f.id; e.servingDescription = f.servingDescription; e.notes = f.notes; e.createdAt = f.createdAt; e.position = i
                insert(e)
                e.meal = m
            }
            added += 1
        }

        let savedIDs = ids(SavedMeal.self, \.id)
        for r in b.savedMeals where !savedIDs.contains(r.id) {
            let s = SavedMeal(name: r.name, type: r.mealType, foodLines: r.foods.map(\.line).joined(separator: "\n"))
            s.id = r.id; s.createdAt = r.createdAt
            insert(s)
            added += 1
        }

        let waterIDs = ids(WaterEntry.self, \.id)
        for r in b.water where !waterIDs.contains(r.id) {
            let w = WaterEntry(amountML: r.amountML, at: r.timestamp, createdAt: r.createdAt)
            w.id = r.id
            insert(w)
            added += 1
        }

        var supplementsByID = Dictionary(((try? fetch(FetchDescriptor<Supplement>())) ?? []).map { ($0.id, $0) },
                                         uniquingKeysWith: { a, _ in a })
        for r in b.supplements where supplementsByID[r.id] == nil {
            let s = Supplement(name: r.name, dosageText: r.dosageText)
            s.id = r.id; s.active = r.active; s.notes = r.notes; s.createdAt = r.createdAt; s.updatedAt = r.updatedAt
            insert(s)
            for sr in r.schedules {
                let sch = SupplementSchedule(daysOfWeek: sr.daysOfWeek, preferredTime: sr.preferredTime, startDate: sr.startDate)
                sch.id = sr.id; sch.reminderEnabled = sr.reminderEnabled; sch.reminderMinutes = sr.reminderTime?.minutes
                sch.endDate = sr.endDate
                insert(sch)
                sch.supplement = s
            }
            supplementsByID[r.id] = s
            added += 1
        }

        let logIDs = ids(SupplementLog.self, \.id)
        for r in b.supplementLogs where !logIDs.contains(r.id) {
            guard let s = supplementsByID[r.supplementID] else { continue }
            let log = SupplementLog(day: r.scheduledDay, scheduleID: r.scheduleID, scheduledMinutes: r.scheduledTime?.minutes)
            log.id = r.id; log.status = r.status; log.takenAt = r.takenAt; log.createdAt = r.createdAt
            insert(log)
            log.supplement = s
            added += 1
        }

        let checkInIDs = ids(DailyCheckIn.self, \.id)
        let checkInDays = Set(((try? fetch(FetchDescriptor<DailyCheckIn>())) ?? []).map(\.day))
        for r in b.checkIns where !checkInIDs.contains(r.id) && !checkInDays.contains(r.day) {
            let c = DailyCheckIn(day: r.day)
            c.id = r.id; c.energy = r.energy; c.mood = r.mood; c.stress = r.stress; c.notes = r.notes; c.createdAt = r.createdAt
            insert(c)
            added += 1
        }

        let gymIDs = ids(GymSession.self, \.id)
        for r in b.gymSessions ?? [] where !gymIDs.contains(r.id) {
            let g = GymSession(at: r.timestamp, calendar: .current)
            g.id = r.id; g.day = r.day; g.focus = r.focus; g.notes = r.notes; g.createdAt = r.createdAt; g.updatedAt = r.updatedAt
            insert(g)
            for (i, er) in r.exercises.enumerated() {
                let e = GymExercise(er.exercise)
                e.id = er.id; e.createdAt = er.createdAt; e.position = i
                insert(e)
                e.session = g
            }
            added += 1
        }

        let proteinIDs = ids(ProteinEntry.self, \.id)
        for r in b.protein ?? [] where !proteinIDs.contains(r.id) {
            let p = ProteinEntry(grams: r.grams, label: r.label, at: r.timestamp, createdAt: r.createdAt)
            p.id = r.id
            insert(p)
            added += 1
        }

        try save()
        return added
    }
}

/// Writes export files to a temporary folder for the share sheet.
enum ExportFiles {
    enum Kind { case all, json, csv }

    static func make(_ kind: Kind, bundle: ExportBundle, now: Date = .now) throws -> URL {
        let stamp = now.formatted(.iso8601.year().month().day())
        let dir = FileManager.default.temporaryDirectory.appending(path: "export-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if kind == .json {
            let url = dir.appending(path: "HealthTrack-Export-\(stamp).json")
            try bundle.jsonData().write(to: url)
            return url
        }
        let folder = dir.appending(path: kind == .all ? "HealthTrack-Export-\(stamp)" : "HealthTrack-Export-\(stamp)-csv",
                                   directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if kind == .all { try bundle.jsonData().write(to: folder.appending(path: "backup.json")) }
        for file in CSVExport.files(for: bundle) {
            try Data(file.contents.utf8).write(to: folder.appending(path: file.name))
        }
        return try zip(folder)
    }

    /// Zips a folder using the system's built-in "prepare for upload" behaviour. No third-party code.
    static func zip(_ folder: URL) throws -> URL {
        let destination = folder.deletingLastPathComponent().appending(path: folder.lastPathComponent + ".zip")
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { zipURL in
            do { try FileManager.default.copyItem(at: zipURL, to: destination) } catch { copyError = error }
        }
        if let error = coordinationError ?? copyError { throw error }
        return destination
    }
}
