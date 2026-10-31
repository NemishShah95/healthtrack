import Foundation

/// The backup format. Deliberately separate from the SwiftData schema so old backups stay readable
/// after the database changes. Rules: only ever ADD optional fields; anything else bumps `currentFormatVersion`.
struct ExportBundle: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    var formatVersion = ExportBundle.currentFormatVersion
    var exportedAt: Date
    var appVersion: String
    var goals: Goals
    var favoriteFoods: [String]
    var meals: [MealRecord]
    var savedMeals: [SavedMealRecord]
    var water: [WaterRecord]
    var supplements: [SupplementRecord]
    var supplementLogs: [SupplementLogRecord]
    var checkIns: [CheckInRecord]

    enum ImportError: Error, Equatable {
        case newerFormat(Int)
    }

    func jsonData() throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }

    static func decode(_ data: Data) throws -> ExportBundle {
        struct Version: Decodable { var formatVersion: Int }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        let version = try d.decode(Version.self, from: data).formatVersion
        guard version <= currentFormatVersion else { throw ImportError.newerFormat(version) }
        return try d.decode(ExportBundle.self, from: data)
    }
}

struct MealRecord: Codable, Equatable, Sendable {
    var id: UUID
    /// "yyyy-MM-dd"
    var day: String
    var timestamp: Date
    /// Time zone the meal was logged in, so window checks don't shift after travel.
    var timeZone: String
    var mealType: MealType
    var customName: String?
    var notes: String
    var qualityRating: Int?
    var createdAt: Date
    var updatedAt: Date
    var foods: [FoodRecord]
}

struct FoodRecord: Codable, Equatable, Sendable {
    var id: UUID
    var foodName: String
    var grams: Double?
    var servingDescription: String?
    var notes: String
    var createdAt: Date
}

struct SavedMealRecord: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var mealType: MealType
    var foods: [ParsedFood]
    var createdAt: Date
}

struct WaterRecord: Codable, Equatable, Sendable {
    var id: UUID
    var timestamp: Date
    var amountML: Int
    var createdAt: Date
}

struct SupplementRecord: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var dosageText: String
    var active: Bool
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var schedules: [ScheduleRecord]
}

struct ScheduleRecord: Codable, Equatable, Sendable {
    var id: UUID
    var daysOfWeek: [Int]
    var preferredTime: DayPart?
    var reminderEnabled: Bool
    var reminderTime: TimeOfDay?
    var startDate: Date
    var endDate: Date?
}

struct SupplementLogRecord: Codable, Equatable, Sendable {
    var id: UUID
    var supplementID: UUID
    var scheduleID: UUID?
    /// "yyyy-MM-dd"
    var scheduledDay: String
    var scheduledTime: TimeOfDay?
    var status: SupplementStatus
    var takenAt: Date?
    var createdAt: Date
}

struct CheckInRecord: Codable, Equatable, Sendable {
    var id: UUID
    /// "yyyy-MM-dd"
    var day: String
    var energy: Int?
    var mood: Int?
    var stress: Int?
    var notes: String
    var createdAt: Date
}

/// CSV is for spreadsheets; JSON is the restorable backup.
enum CSVExport {
    static func files(for b: ExportBundle, timeZone: TimeZone = .current) -> [(name: String, contents: String)] {
        let stamp = Date.ISO8601FormatStyle(timeZone: timeZone)
        func t(_ d: Date?) -> String { d.map { $0.formatted(stamp) } ?? "" }
        func day(_ d: Date) -> String { d.formatted(stamp.year().month().day()) }
        func s<T>(_ v: T?) -> String { v.map { "\($0)" } ?? "" }

        return [
            ("meals.csv", table(
                ["id", "day", "timestamp", "time_zone", "meal_type", "custom_name", "quality_rating", "food_count", "notes"],
                b.meals.map { [$0.id.uuidString, $0.day, t($0.timestamp), $0.timeZone, $0.mealType.rawValue,
                               s($0.customName), s($0.qualityRating), String($0.foods.count), $0.notes] })),
            ("food_entries.csv", table(
                ["id", "meal_id", "food_name", "grams", "serving", "notes", "created_at"],
                b.meals.flatMap { m in m.foods.map {
                    [$0.id.uuidString, m.id.uuidString, $0.foodName, s($0.grams), s($0.servingDescription), $0.notes, t($0.createdAt)]
                } })),
            ("water.csv", table(
                ["id", "timestamp", "amount_ml"],
                b.water.map { [$0.id.uuidString, t($0.timestamp), String($0.amountML)] })),
            ("supplements.csv", table(
                ["id", "name", "dosage", "active", "notes"],
                b.supplements.map { [$0.id.uuidString, $0.name, $0.dosageText, String($0.active), $0.notes] })),
            ("supplement_schedules.csv", table(
                ["id", "supplement_id", "days_of_week", "preferred_time", "reminder_enabled", "reminder_time", "start_date", "end_date"],
                b.supplements.flatMap { sup in sup.schedules.map {
                    [$0.id.uuidString, sup.id.uuidString, $0.daysOfWeek.map(String.init).joined(separator: " "),
                     s($0.preferredTime?.rawValue), String($0.reminderEnabled),
                     $0.reminderTime.map { String(format: "%02d:%02d", $0.hour, $0.minute) } ?? "",
                     day($0.startDate), $0.endDate.map(day) ?? ""]
                } })),
            ("supplement_logs.csv", table(
                ["id", "supplement_id", "schedule_id", "scheduled_day", "status", "taken_at"],
                b.supplementLogs.map { [$0.id.uuidString, $0.supplementID.uuidString, s($0.scheduleID?.uuidString), $0.scheduledDay, $0.status.rawValue, t($0.takenAt)] })),
            ("check_ins.csv", table(
                ["id", "day", "energy", "mood", "stress", "notes"],
                b.checkIns.map { [$0.id.uuidString, $0.day, s($0.energy), s($0.mood), s($0.stress), $0.notes] })),
        ]
    }

    static func table(_ header: [String], _ rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
