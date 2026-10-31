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
    }
}
