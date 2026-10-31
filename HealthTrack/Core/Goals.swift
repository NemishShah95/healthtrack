import Foundation

/// The user's own targets. Every value is a default the user can change in Settings.
struct Goals: Codable, Equatable, Sendable {
    var bedtime = TimeOfDay(23, 0)
    var wakeTime = TimeOfDay(7, 0)
    var sleepToleranceMinutes = 30
    var sleepTargetMinutes = 7 * 60
    var waterTargetML = 2500
    var stepTarget = 8000
    var workoutsPerWeek = 4
    var mealWindows = MealWindow.defaults
    /// A placeholder until you set your own; HealthTrack never recommends an intake.
    var proteinTargetGrams = 100

    func isBedtimeOnTarget(_ t: TimeOfDay) -> Bool { abs(bedtime.signedMinutes(to: t)) <= sleepToleranceMinutes }
    func isWakeOnTarget(_ t: TimeOfDay) -> Bool { abs(wakeTime.signedMinutes(to: t)) <= sleepToleranceMinutes }
}

extension Goals {
    /// Missing keys fall back to defaults, so adding a goal later never breaks stored settings or old backups.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Goals()
        bedtime = try c.decodeIfPresent(TimeOfDay.self, forKey: .bedtime) ?? d.bedtime
        wakeTime = try c.decodeIfPresent(TimeOfDay.self, forKey: .wakeTime) ?? d.wakeTime
        sleepToleranceMinutes = try c.decodeIfPresent(Int.self, forKey: .sleepToleranceMinutes) ?? d.sleepToleranceMinutes
        sleepTargetMinutes = try c.decodeIfPresent(Int.self, forKey: .sleepTargetMinutes) ?? d.sleepTargetMinutes
        waterTargetML = try c.decodeIfPresent(Int.self, forKey: .waterTargetML) ?? d.waterTargetML
        stepTarget = try c.decodeIfPresent(Int.self, forKey: .stepTarget) ?? d.stepTarget
        workoutsPerWeek = try c.decodeIfPresent(Int.self, forKey: .workoutsPerWeek) ?? d.workoutsPerWeek
        mealWindows = try c.decodeIfPresent([MealType: MealWindow].self, forKey: .mealWindows) ?? d.mealWindows
        proteinTargetGrams = try c.decodeIfPresent(Int.self, forKey: .proteinTargetGrams) ?? d.proteinTargetGrams
    }
}

/// Which optional reminders are on. Everything is off by default: no spam.
/// (Supplement reminders are set per supplement; the app-refresh reminder lives in AppSettings.)
struct ReminderSettings: Codable, Equatable, Sendable {
    var meals = false
    var water = false
    var waterTimes = [TimeOfDay(11), TimeOfDay(15), TimeOfDay(18)]
    var bedtime = false
    var checkIn = false
    var checkInTime = TimeOfDay(21)
    var backup = false
}

extension ReminderSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ReminderSettings()
        meals = try c.decodeIfPresent(Bool.self, forKey: .meals) ?? d.meals
        water = try c.decodeIfPresent(Bool.self, forKey: .water) ?? d.water
        waterTimes = try c.decodeIfPresent([TimeOfDay].self, forKey: .waterTimes) ?? d.waterTimes
        bedtime = try c.decodeIfPresent(Bool.self, forKey: .bedtime) ?? d.bedtime
        checkIn = try c.decodeIfPresent(Bool.self, forKey: .checkIn) ?? d.checkIn
        checkInTime = try c.decodeIfPresent(TimeOfDay.self, forKey: .checkInTime) ?? d.checkInTime
        backup = try c.decodeIfPresent(Bool.self, forKey: .backup) ?? d.backup
    }
}
