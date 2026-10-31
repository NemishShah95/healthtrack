import Foundation
import SwiftData

/// Version 1 of the on-device database.
///
/// Once HealthTrack is installed on the iPhone (M18) these models are FROZEN. Change them only by
/// adding `SchemaV2` and a migration stage. See DATA_SAFETY.md → Safe upgrade procedure.
/// Every property has a default so lightweight migrations can always add columns.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Meal.self, FoodEntry.self, SavedMeal.self, WaterEntry.self, Supplement.self,
         SupplementSchedule.self, SupplementLog.self, DailyCheckIn.self, AppSettings.self]
    }

    @Model final class Meal {
        var id: UUID = UUID()
        /// "yyyy-MM-dd" of the day it was eaten.
        var day: String = ""
        var timestamp: Date = Date()
        /// Time zone it was logged in, so window checks don't shift after travel.
        var timeZoneID: String = ""
        var mealTypeRaw: String = "breakfast"
        var customName: String?
        var notes: String = ""
        var qualityRating: Int?
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \FoodEntry.meal)
        var foods: [FoodEntry] = []

        init(type: MealType, at timestamp: Date, calendar: Calendar) {
            mealTypeRaw = type.rawValue
            self.timestamp = timestamp
            day = DayKey.of(timestamp, calendar: calendar)
            timeZoneID = calendar.timeZone.identifier
        }
    }

    @Model final class FoodEntry {
        var id: UUID = UUID()
        var meal: Meal?
        var foodName: String = ""
        var grams: Double?
        var servingDescription: String?
        var notes: String = ""
        var createdAt: Date = Date()

        init(name: String, grams: Double?) {
            foodName = name
            self.grams = MealRoutine.cleanGrams(grams)
        }
    }

    /// "Usual breakfast" etc. Foods are stored as text lines ("oats 80 g") and re-parsed when used.
    @Model final class SavedMeal {
        var id: UUID = UUID()
        var name: String = ""
        var mealTypeRaw: String = "breakfast"
        var foodLines: String = ""
        var createdAt: Date = Date()

        init(name: String, type: MealType, foodLines: String) {
            self.name = name
            mealTypeRaw = type.rawValue
            self.foodLines = foodLines
        }
    }

    @Model final class WaterEntry {
        var id: UUID = UUID()
        var timestamp: Date = Date()
        var amountML: Int = 0
        var createdAt: Date = Date()

        init(amountML: Int, at timestamp: Date, createdAt: Date) {
            self.amountML = amountML
            self.timestamp = timestamp
            self.createdAt = createdAt
        }
    }

    @Model final class Supplement {
        var id: UUID = UUID()
        var name: String = ""
        var dosageText: String = ""
        var active: Bool = true
        var notes: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \SupplementSchedule.supplement)
        var schedules: [SupplementSchedule] = []
        @Relationship(deleteRule: .cascade, inverse: \SupplementLog.supplement)
        var logs: [SupplementLog] = []

        init(name: String, dosageText: String = "") {
            self.name = name
            self.dosageText = dosageText
        }
    }

    @Model final class SupplementSchedule {
        var id: UUID = UUID()
        var supplement: Supplement?
        /// Calendar weekdays, 1 = Sunday … 7 = Saturday. Empty = every day.
        var daysOfWeek: [Int] = []
        var preferredTimeRaw: String?
        var reminderEnabled: Bool = false
        /// Minutes after midnight.
        var reminderMinutes: Int?
        var startDate: Date = Date()
        var endDate: Date?

        init(daysOfWeek: [Int] = [], preferredTime: DayPart? = .morning, startDate: Date) {
            self.daysOfWeek = daysOfWeek
            preferredTimeRaw = preferredTime?.rawValue
            self.startDate = startDate
        }
    }

    /// One scheduled dose on one day.
    @Model final class SupplementLog {
        var id: UUID = UUID()
        var supplement: Supplement?
        var scheduleID: UUID?
        /// "yyyy-MM-dd"
        var day: String = ""
        var scheduledMinutes: Int?
        var statusRaw: String = "pending"
        var takenAt: Date?
        var createdAt: Date = Date()

        init(day: String, scheduleID: UUID?, scheduledMinutes: Int?) {
            self.day = day
            self.scheduleID = scheduleID
            self.scheduledMinutes = scheduledMinutes
        }
    }

    @Model final class DailyCheckIn {
        var id: UUID = UUID()
        /// "yyyy-MM-dd"
        var day: String = ""
        var energy: Int?
        var mood: Int?
        var stress: Int?
        var notes: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        init(day: String) { self.day = day }
    }

    /// Single row: goals, preferences and app-installation metadata.
    @Model final class AppSettings {
        /// JSON-encoded `Goals`; decoding fills missing keys with defaults.
        var goalsData: Data = Data()
        var favoriteFoods: [String] = []
        var hasCompletedOnboarding: Bool = false
        var installationDate: Date?
        var lastProvisioningRefreshDate: Date?
        /// App binary date + signing profile expiry at the last launch. A change means Xcode reinstalled the app.
        var installFingerprint: String?
        var refreshReminderEnabled: Bool = true
        /// JSON-encoded `ReminderSettings`.
        var remindersData: Data = Data()
        var lastExportDate: Date?

        init() {}
    }
}

typealias Meal = SchemaV1.Meal
typealias FoodEntry = SchemaV1.FoodEntry
typealias SavedMeal = SchemaV1.SavedMeal
typealias WaterEntry = SchemaV1.WaterEntry
typealias Supplement = SchemaV1.Supplement
typealias SupplementSchedule = SchemaV1.SupplementSchedule
typealias SupplementLog = SchemaV1.SupplementLog
typealias DailyCheckIn = SchemaV1.DailyCheckIn
typealias AppSettings = SchemaV1.AppSettings

enum HealthTrackMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// MARK: - Typed accessors (outside the frozen schema)

extension Meal {
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .custom }
        set { mealTypeRaw = newValue.rawValue }
    }
    var title: String { mealType == .custom ? (customName ?? "Meal") : mealType.rawValue.capitalized }
    var sortedFoods: [FoodEntry] { foods.sorted { $0.createdAt < $1.createdAt } }
    /// Local wall-clock time in the zone it was logged in.
    var localTime: TimeOfDay {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return TimeOfDay(of: timestamp, in: cal)
    }
}

extension SavedMeal {
    var mealType: MealType { MealType(rawValue: mealTypeRaw) ?? .custom }
    var foods: [ParsedFood] { MealRoutine.parseFoods(foodLines) }
}

extension SupplementSchedule {
    var preferredTime: DayPart? { preferredTimeRaw.flatMap(DayPart.init(rawValue:)) }
    var reminderTime: TimeOfDay? { reminderMinutes.map { TimeOfDay(0, $0) } }
    func rule(isActive: Bool) -> SupplementRule {
        SupplementRule(weekdays: Set(daysOfWeek), startDate: startDate, endDate: endDate, isActive: isActive)
    }
}

extension SupplementLog {
    var status: SupplementStatus {
        get { SupplementStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

extension AppSettings {
    var goals: Goals {
        get { (try? JSONDecoder().decode(Goals.self, from: goalsData)) ?? Goals() }
        set { if let data = try? JSONEncoder().encode(newValue) { goalsData = data } }
    }

    var reminders: ReminderSettings {
        get { (try? JSONDecoder().decode(ReminderSettings.self, from: remindersData)) ?? ReminderSettings() }
        set { if let data = try? JSONEncoder().encode(newValue) { remindersData = data } }
    }
}
