import Foundation
import SwiftData
import Testing
@testable import HealthTrack

@MainActor
@Suite struct PersistenceTests {
    let cal = calendar()

    func memoryContext() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(inMemory: true))
    }

    func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "HealthTrackTests-\(UUID().uuidString)/HealthTrack.store")
    }

    @Test func mealCRUDAndCascadeDelete() throws {
        let ctx = try memoryContext()
        let meal = ctx.logMeal(.breakfast, foods: MealRoutine.parseFoods("oats 80 g\nbanana\nyogurt 0 g"),
                               at: date("2026-10-26 08:10", cal), calendar: cal)
        try ctx.save()

        let fetched = ctx.meals(onDay: "2026-10-26")
        #expect(fetched.count == 1)
        #expect(fetched[0].sortedFoods.map(\.foodName) == ["oats", "banana", "yogurt"])
        #expect(fetched[0].sortedFoods.map(\.grams) == [80, nil, nil])   // zero grams stored as "no quantity"
        #expect(fetched[0].localTime == TimeOfDay(8, 10))

        meal.notes = "edited"
        try ctx.save()
        #expect(ctx.meals(onDay: "2026-10-26")[0].notes == "edited")

        ctx.delete(meal)
        try ctx.save()
        #expect(ctx.meals(onDay: "2026-10-26").isEmpty)
        #expect(try ctx.fetchCount(FetchDescriptor<FoodEntry>()) == 0)
    }

    @Test func quickMealDuplicateAndUsualMeal() throws {
        let ctx = try memoryContext()
        let quick = ctx.logMeal(.lunch, at: date("2026-10-26 12:30", cal), calendar: cal)   // "Lunch ✓"
        #expect(quick.foods.isEmpty)

        let breakfast = ctx.logMeal(.breakfast, foods: [.init(name: "oats", grams: 80), .init(name: "banana", grams: 120)],
                                    at: date("2026-10-26 08:00", cal), calendar: cal)
        let copy = ctx.duplicate(breakfast, at: date("2026-10-27 08:05", cal), calendar: cal)
        #expect(copy.day == "2026-10-27")
        #expect(copy.sortedFoods.map(\.foodName) == ["oats", "banana"])

        let usual = ctx.saveAsUsual(breakfast, name: "Usual breakfast")
        #expect(usual.foods == [.init(name: "oats", grams: 80), .init(name: "banana", grams: 120)])
        let fromUsual = ctx.logSavedMeal(usual, at: date("2026-10-28 08:00", cal), calendar: cal)
        #expect(fromUsual.sortedFoods.map(\.grams) == [80, 120])
        #expect(ctx.recentFoods() == ["oats", "banana"] || ctx.recentFoods() == ["banana", "oats"])
    }

    @Test func waterDuplicateTapsAndTotals() throws {
        let ctx = try memoryContext()
        let t0 = date("2026-10-26 09:00", cal)
        #expect(ctx.logWater(250, at: t0, now: t0) != nil)
        #expect(ctx.logWater(250, at: t0, now: t0 + 0.5) == nil)    // bounce
        #expect(ctx.logWater(500, at: t0, now: t0 + 0.6) != nil)    // different amount is fine
        #expect(ctx.logWater(250, at: t0, now: t0 + 5) != nil)
        #expect(ctx.logWater(0, now: t0 + 10) == nil)
        #expect(ctx.logWater(9000, now: t0 + 20) == nil)
        let day = ctx.water(from: date("2026-10-26", cal), to: date("2026-10-27", cal))
        #expect(day.reduce(0) { $0 + $1.amountML } == 1000)
    }

    @Test func supplementLogsSyncIdempotentlyAndMarkMissed() throws {
        let ctx = try memoryContext()
        let iron = Supplement(name: "Iron")
        ctx.insert(iron)
        let schedule = SupplementSchedule(daysOfWeek: [2, 4, 6], startDate: date("2026-10-01", cal))  // Mon/Wed/Fri
        ctx.insert(schedule)
        schedule.supplement = iron

        let today = date("2026-10-30 10:00", cal)  // Friday
        ctx.syncSupplementLogs(today: today, days: 13, calendar: cal)   // 2026-10-17 … 10-30
        ctx.syncSupplementLogs(today: today, days: 13, calendar: cal)
        try ctx.save()

        let logs = ctx.supplementLogs(from: "2026-10-17", through: "2026-10-30")
        #expect(logs.count == 6)                                       // 19, 21, 23, 26, 28, 30
        #expect(logs.filter { $0.day < "2026-10-30" }.allSatisfy { $0.status == .missed })
        #expect(logs.first { $0.day == "2026-10-30" }?.status == .pending)

        ctx.markAllTaken(onDay: "2026-10-30", at: today)
        #expect(logs.first { $0.day == "2026-10-30" }?.status == .taken)

        // Pausing doesn't rewrite history, and no new doses appear.
        ctx.setActive(false, for: iron, today: today, calendar: cal)
        ctx.syncSupplementLogs(today: date("2026-11-02 10:00", cal), days: 3, calendar: cal)
        #expect(ctx.supplementLogs(from: "2026-10-31", through: "2026-11-02").isEmpty)
        #expect(ctx.supplementLogs(from: "2026-10-17", through: "2026-10-30").count == 6)
    }

    @Test func goalsPersistInSettings() throws {
        let ctx = try memoryContext()
        var goals = ctx.settings().goals
        #expect(goals == Goals())
        goals.waterTargetML = 3000
        ctx.settings().goals = goals
        try ctx.save()
        #expect(ctx.settings().goals.waterTargetML == 3000)
        #expect(try ctx.fetchCount(FetchDescriptor<AppSettings>()) == 1)
    }

    @Test func dataSurvivesReopeningTheStore() throws {
        // Equivalent of quitting and relaunching the app (or installing an update over it).
        let url = tempStoreURL()
        do {
            let ctx = ModelContext(try Persistence.makeContainer(url: url))
            ctx.logMeal(.dinner, foods: [.init(name: "rice", grams: 150)], at: date("2026-10-26 19:30", cal), calendar: cal)
            ctx.logWater(500, now: date("2026-10-26 10:00", cal))
            ctx.checkIn(onDay: "2026-10-26").energy = 4
            try ctx.save()
        }
        let reopened = ModelContext(try Persistence.makeContainer(url: url))
        #expect(reopened.meals(onDay: "2026-10-26").first?.sortedFoods.first?.grams == 150)
        #expect(try reopened.fetchCount(FetchDescriptor<WaterEntry>()) == 1)
        #expect(reopened.existingCheckIn(onDay: "2026-10-26")?.energy == 4)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test func exportImportRoundTripWithoutDuplicates() throws {
        let source = try memoryContext()
        source.logMeal(.breakfast, foods: [.init(name: "oats", grams: 80)], at: date("2026-10-26 08:00", cal), calendar: cal)
        source.logWater(250, now: date("2026-10-26 09:00", cal))
        let d = Supplement(name: "Vitamin D", dosageText: "1000 IU")
        source.insert(d)
        let sch = SupplementSchedule(startDate: date("2026-10-20", cal))
        source.insert(sch)
        sch.supplement = d
        source.syncSupplementLogs(today: date("2026-10-26 12:00", cal), days: 2, calendar: cal)
        source.checkIn(onDay: "2026-10-26").mood = 5
        source.settings().favoriteFoods = ["oats"]
        try source.save()

        let bundle = try ExportBundle.decode(source.exportBundle(appVersion: "test").jsonData())
        #expect(bundle.meals.count == 1 && bundle.water.count == 1 && bundle.supplements.count == 1)
        #expect(bundle.supplementLogs.count == 3 && bundle.checkIns.count == 1)

        let target = try memoryContext()
        #expect(try target.importBundle(bundle) == 7)       // 1 meal, 1 water, 1 supplement, 3 logs, 1 check-in
        #expect(try target.importBundle(bundle) == 0)       // second import adds nothing
        #expect(target.exportBundle(appVersion: "test", now: bundle.exportedAt) == bundle)
    }
}

@MainActor
@Test func sampleDataSeeds90DaysOnceOnly() throws {
    let cal = calendar()
    let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
    let now = date("2026-10-31 12:00", cal)
    SampleData.seedIfEmpty(ctx, now: now, calendar: cal)
    let meals = try ctx.fetchCount(FetchDescriptor<Meal>())
    #expect(meals > 200)
    #expect(try ctx.fetchCount(FetchDescriptor<Supplement>()) == 5)
    #expect(ctx.supplementLogs(from: "2026-08-03", through: "2026-10-31").count > 350)
    SampleData.seedIfEmpty(ctx, now: now, calendar: cal)
    #expect(try ctx.fetchCount(FetchDescriptor<Meal>()) == meals)
}
