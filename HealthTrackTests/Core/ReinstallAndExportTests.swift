import Foundation
import Testing
@testable import HealthTrack

// MARK: - Reinstall reminder

@Test func suggestedRefreshIsSixDaysLaterOrBeforeProfileExpiry() {
    let cal = calendar(), last = date("2026-10-20 10:00", cal)   // crosses London DST end on 10-25
    func next(_ expiry: String?) -> Date {
        ReinstallSchedule.nextSuggestedRefresh(lastRefresh: last, profileExpiration: expiry.map { date($0, cal) }, calendar: cal)
    }
    #expect(next(nil) == date("2026-10-26 10:00", cal))
    #expect(next("2026-10-25 10:00") == date("2026-10-24 10:00", cal))
    #expect(next("2026-10-27 10:00") == date("2026-10-26 10:00", cal))
}

@Test func refreshWarningStates() {
    let cal = calendar(), nextRefresh = date("2026-10-26 10:00", cal)
    func status(_ now: String) -> RefreshStatus {
        ReinstallSchedule.status(now: date(now, cal), nextSuggested: nextRefresh, calendar: cal)
    }
    #expect(status("2026-10-23 09:00") == .ok)
    #expect(status("2026-10-24 23:59") == .dueSoon(nextRefresh))   // 2 calendar days, 34h across DST
    #expect(status("2026-10-25 08:00") == .dueSoon(nextRefresh))
    #expect(status("2026-10-26 07:00") == .dueToday)
    #expect(status("2026-10-28 07:00") == .dueToday)
}

// MARK: - Export

private func sampleBundle() -> ExportBundle {
    let t = Date(timeIntervalSince1970: 1_792_000_000)  // whole seconds: ISO 8601 keeps second precision
    let mealID = UUID(), supplementID = UUID()
    return ExportBundle(
        exportedAt: t, appVersion: "1.0 (1)", goals: Goals(), favoriteFoods: ["oats", "banana"],
        meals: [MealRecord(
            id: mealID, day: "2026-10-14", timestamp: t, timeZone: "Asia/Kolkata", mealType: .breakfast, customName: nil,
            notes: "with \"honey\", warm\nsecond line", qualityRating: 4, createdAt: t, updatedAt: t,
            foods: [FoodRecord(id: UUID(), foodName: "oats", grams: 80.5, servingDescription: nil, notes: "", createdAt: t),
                    FoodRecord(id: UUID(), foodName: "banana, ripe", grams: nil, servingDescription: "1 medium", notes: "", createdAt: t)])],
        savedMeals: [SavedMealRecord(id: UUID(), name: "Usual breakfast", mealType: .breakfast,
                                     foods: [.init(name: "oats", grams: 80)], createdAt: t)],
        water: [WaterRecord(id: UUID(), timestamp: t, amountML: 250, createdAt: t),
                WaterRecord(id: UUID(), timestamp: t + 60, amountML: 500, createdAt: t + 60)],
        supplements: [SupplementRecord(
            id: supplementID, name: "Vitamin D3 (cholecalciferol) 2000 IU softgel with breakfast", dosageText: "1 capsule",
            active: true, notes: "", createdAt: t, updatedAt: t,
            schedules: [ScheduleRecord(id: UUID(), daysOfWeek: [2, 4, 6], preferredTime: .morning, reminderEnabled: true,
                                       reminderTime: .init(8, 15), startDate: t, endDate: nil)])],
        supplementLogs: [SupplementLogRecord(id: UUID(), supplementID: supplementID, scheduleID: nil, scheduledDay: "2026-10-14", scheduledTime: .init(8, 15),
                                             status: .taken, takenAt: t, createdAt: t),
                         SupplementLogRecord(id: UUID(), supplementID: supplementID, scheduleID: UUID(), scheduledDay: "2026-10-15", scheduledTime: nil,
                                             status: .missed, takenAt: nil, createdAt: t)],
        checkIns: [CheckInRecord(id: UUID(), day: "2026-10-14", energy: 4, mood: nil, stress: 2, notes: "ok", createdAt: t)])
}

@Test func jsonExportRoundTrips() throws {
    let bundle = sampleBundle()
    #expect(try ExportBundle.decode(bundle.jsonData()) == bundle)
}

@Test func backupFromANewerAppVersionIsRejected() throws {
    var bundle = sampleBundle()
    bundle.formatVersion = 99
    let data = try bundle.jsonData()
    #expect(throws: ExportBundle.ImportError.newerFormat(99)) { try ExportBundle.decode(data) }
}

@Test func goalsFromOlderDataFillMissingKeysWithDefaults() throws {
    let goals = try JSONDecoder().decode(Goals.self, from: Data(#"{"waterTargetML": 3000}"#.utf8))
    #expect(goals.waterTargetML == 3000)
    #expect(goals.bedtime == Goals().bedtime && goals.mealWindows == MealWindow.defaults)
}

@Test func csvEscaping() {
    #expect(CSVExport.escape("plain") == "plain")
    #expect(CSVExport.escape("a,b") == #""a,b""#)
    #expect(CSVExport.escape(#"say "hi""#) == #""say ""hi""""#)
    #expect(CSVExport.escape("line\nbreak") == "\"line\nbreak\"")
}

@Test func csvExportParsesAndCoversAllManualData() throws {
    let bundle = sampleBundle()
    let files = Dictionary(uniqueKeysWithValues: CSVExport.files(for: bundle, timeZone: TimeZone(identifier: "UTC")!).map { ($0.name, $0.contents) })
    let expectedRows = [
        "meals.csv": 1, "food_entries.csv": 2, "water.csv": 2, "supplements.csv": 1,
        "supplement_schedules.csv": 1, "supplement_logs.csv": 2, "check_ins.csv": 1,
    ]
    #expect(Set(files.keys) == Set(expectedRows.keys))
    for (name, count) in expectedRows {
        let rows = parseCSV(try #require(files[name]))
        #expect(rows.count == count + 1, "\(name)")
        #expect(rows.allSatisfy { $0.count == rows[0].count }, "\(name) has ragged rows")
    }
    let meal = parseCSV(files["meals.csv"]!)[1]
    #expect(meal.last == bundle.meals[0].notes)
    #expect(parseCSV(files["food_entries.csv"]!)[2][2] == "banana, ripe")
}

/// Minimal RFC 4180 reader, enough to prove the export is well-formed.
private func parseCSV(_ s: String) -> [[String]] {
    var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
    let chars = Array(s)
    var i = 0
    while i < chars.count {
        let c = chars[i]
        if quoted {
            if c == "\"" {
                if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { quoted = false }
            } else {
                field.append(c)
            }
        } else if c == "\"" {
            quoted = true
        } else if c == "," {
            row.append(field); field = ""
        } else if c == "\r\n" || c == "\n" {
            row.append(field); rows.append(row); row = []; field = ""
        } else {
            field.append(c)
        }
        i += 1
    }
    return rows
}
