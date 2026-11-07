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
        source.logMeal(.breakfast, foods: [.init(name: "oats", grams: 80), .init(name: "banana", grams: 120), .init(name: "almonds", grams: nil)],
                       at: date("2026-10-26 08:00", cal), calendar: cal)
        source.logWater(250, now: date("2026-10-26 09:00", cal))
        let d = Supplement(name: "Vitamin D", dosageText: "1000 IU")
        source.insert(d)
        let sch = SupplementSchedule(startDate: date("2026-10-20", cal))
        source.insert(sch)
        sch.supplement = d
        source.syncSupplementLogs(today: date("2026-10-26 12:00", cal), days: 2, calendar: cal)
        source.logVitamin(d, at: date("2026-10-26 13:00", cal), now: date("2026-10-26 13:00", cal), calendar: cal)   // journal entry
        source.checkIn(onDay: "2026-10-26").mood = 5
        source.settings().favoriteFoods = ["oats"]
        source.logGym(focus: [.legs], exercises: GymLog.parse("Squat 5x5 100 kg\nBike 10 min"), at: date("2026-10-26 18:00", cal), calendar: cal)
        source.logProtein(30, label: "whey", at: date("2026-10-26 10:00", cal), now: date("2026-10-26 10:00", cal))
        try source.save()

        let bundle = try ExportBundle.decode(source.exportBundle(appVersion: "test").jsonData())
        #expect(bundle.meals.count == 1 && bundle.water.count == 1 && bundle.supplements.count == 1)
        #expect(bundle.supplementLogs.count == 4 && bundle.checkIns.count == 1)
        #expect(bundle.supplementLogs.filter { $0.scheduleID == nil }.count == 1)

        let target = try memoryContext()
        #expect(bundle.gymSessions?.first?.exercises.count == 2 && bundle.protein?.count == 1)
        #expect(try target.importBundle(bundle) == 10)      // + 1 gym session, 1 protein entry, 1 vitamin journal entry
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
    #expect(try ctx.fetchCount(FetchDescriptor<Supplement>()) == 6)   // 5 scheduled + Zinc as needed
    #expect(ctx.supplementLogs(from: "2026-08-03", through: "2026-10-31").count > 350)
    SampleData.seedIfEmpty(ctx, now: now, calendar: cal)
    #expect(try ctx.fetchCount(FetchDescriptor<Meal>()) == meals)
}

@MainActor
@Test func exportFilesAreWrittenAndZipped() throws {
    let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
    ctx.logMeal(.lunch, foods: [.init(name: "dal, rice", grams: 300)])
    let bundle = ctx.exportBundle(appVersion: "test")
    let json = try ExportFiles.make(.json, bundle: bundle)
    #expect(json.lastPathComponent.hasPrefix("HealthTrack-Export-") && json.pathExtension == "json")
    #expect(try ExportBundle.decode(Data(contentsOf: json)).meals.count == 1)
    for kind in [ExportFiles.Kind.all, .csv] {
        let zip = try ExportFiles.make(kind, bundle: bundle)
        let bytes = try Data(contentsOf: zip)
        #expect(zip.pathExtension == "zip" && bytes.starts(with: [0x50, 0x4B]))   // "PK" zip signature
    }
}

@Test func reminderSettingsDecodeWithMissingKeys() throws {
    let r = try JSONDecoder().decode(ReminderSettings.self, from: Data(#"{"water": true}"#.utf8))
    #expect(r.water && !r.meals && r.waterTimes.count == 3)
}

@MainActor
@Suite struct GymAndProteinTests {
    let cal = calendar()

    @Test func gymSessionsLogEditRepeatAndSuggest() throws {
        let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
        let monday = ctx.logGym(focus: [.chest, .arms], exercises: GymLog.parse("Bench press 3x10 60 kg\nCurl 3x12 12 kg"),
                                at: date("2026-10-26 18:00", cal), calendar: cal)
        try ctx.save()
        #expect(monday.day == "2026-10-26" && monday.title == "Chest · Arms")
        #expect(monday.sortedExercises.map(\.name) == ["Bench press", "Curl"])

        ctx.replaceExercises(of: monday, with: GymLog.parse("Bench press 3x8 65 kg"))
        try ctx.save()
        #expect(monday.sortedExercises.map(\.parsed.line) == ["Bench press 3x8 65 kg"])
        #expect(try ctx.fetchCount(FetchDescriptor<GymExercise>()) == 1)

        let last = try #require(ctx.lastGymSession(before: "2026-10-28"))
        let thursday = ctx.duplicate(last, at: date("2026-10-29 18:00", cal), calendar: cal)
        #expect(thursday.day == "2026-10-29" && thursday.focus == [.chest, .arms])
        #expect(ctx.recentExercises() == [ParsedExercise(name: "Bench press", sets: 3, reps: 8, weightKg: 65)])
        #expect(ctx.trainingLog().count == 2)

        let goal = TrainingGoal(target: ParsedExercise(name: "Bench press", sets: 3, reps: 8), timesPerWeek: 2)
        ctx.saveTrainingGoal(goal)
        var edited = goal
        edited.timesPerWeek = 3
        ctx.saveTrainingGoal(edited)                                    // same id: replaced, not added
        #expect(ctx.settings().goals.trainingGoals == [edited])
        ctx.deleteTrainingGoal(id: goal.id)
        #expect(ctx.settings().goals.trainingGoals.isEmpty)
        #expect(ctx.gymSessions(from: "2026-10-26", through: "2026-10-31").count == 2)

        ctx.delete(monday)
        try ctx.save()
        #expect(try ctx.fetchCount(FetchDescriptor<GymExercise>()) == 1)   // cascade
    }

    @Test func proteinLoggingGuardsBadInputAndDoubleTaps() throws {
        let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
        let t = date("2026-10-26 09:00", cal)
        #expect(ctx.logProtein(20, at: t, now: t) != nil)
        #expect(ctx.logProtein(20, at: t, now: t + 0.5) == nil)
        #expect(ctx.logProtein(30, label: " eggs ", at: t, now: t + 0.6)?.label == "eggs")
        #expect(ctx.logProtein(0, now: t + 9) == nil && ctx.logProtein(500, now: t + 10) == nil)
        #expect(ctx.protein(from: date("2026-10-26", cal), to: date("2026-10-27", cal)).reduce(0) { $0 + $1.grams } == 50)
    }

    @Test func journaledGymCountsAsAWorkoutButNeverTwice() throws {
        let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
        let watch = WorkoutSummary(start: date("2026-10-26 18:05", cal), end: date("2026-10-26 19:00", cal), activityName: "Strength Training")
        let health = HealthSnapshot(steps: ["2026-10-26": 8000], workouts: [watch])
        ctx.logGym(focus: [.chest], exercises: [], at: date("2026-10-26 18:00", cal), calendar: cal)   // same session as the watch
        ctx.logGym(focus: [.legs], exercises: [], at: date("2026-10-28 18:00", cal), calendar: cal)    // journal only
        ctx.logProtein(40, at: date("2026-10-28 09:00", cal), now: date("2026-10-28 09:00", cal))
        let now = date("2026-10-28 21:00", cal)
        let records = ctx.dayRecords(from: date("2026-10-26", cal), through: now, health: health, goals: Goals(), now: now, calendar: cal)
        #expect(records.map(\.workouts) == [1, 0, 1])
        #expect(records.last?.facts.workoutsInLast7Days == 2)
        #expect(records.last?.protein == 40 && records[1].protein == nil)
        #expect(records.last?.bodyParts == [.legs])
        #expect(ctx.workoutsThisWeek(containing: now, health: health, goals: Goals(), now: now, calendar: cal) == 2)
    }
}

@MainActor
@Suite struct VitaminJournalTests {
    let cal = calendar()
    let now = date("2026-10-28 10:00", calendar())

    @Test func journalEntriesAreTakenButNeverCountInAdherence() throws {
        let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
        let vitaminD = Supplement(name: "Vitamin D")
        ctx.insert(vitaminD)
        let daily = SupplementSchedule(startDate: date("2026-10-20", cal))
        ctx.insert(daily)
        daily.supplement = vitaminD
        let zinc = Supplement(name: "Zinc")            // as needed: no schedule
        ctx.insert(zinc)
        ctx.syncSupplementLogs(today: now, days: 3, calendar: cal)
        #expect(zinc.logs.isEmpty)                     // as-needed vitamins never get pending or missed doses

        #expect(ctx.logVitamin(zinc, at: now, now: now, calendar: cal) != nil)
        #expect(ctx.logVitamin(zinc, at: now, now: now + 0.5, calendar: cal) == nil)       // double-tap
        #expect(ctx.logVitamin(vitaminD, at: now, now: now + 1, calendar: cal) != nil)     // an extra dose on top of the schedule

        let today = ctx.supplementLogs(from: "2026-10-28", through: "2026-10-28")
        #expect(today.filter(\.isJournal).count == 2 && today.filter(\.isJournal).allSatisfy { $0.status == .taken })
        let record = try #require(ctx.dayRecords(from: now, through: now, health: HealthSnapshot(), goals: Goals(), now: now, calendar: cal).first)
        #expect(record.facts.supplementStatuses == [.pending])   // only the scheduled dose is judged
    }

    @Test func switchingToAsNeededDropsPendingDosesAndKeepsHistory() throws {
        let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
        let iron = Supplement(name: "Iron")
        ctx.insert(iron)
        let schedule = SupplementSchedule(startDate: date("2026-10-20", cal))
        ctx.insert(schedule)
        schedule.supplement = iron
        ctx.syncSupplementLogs(today: now, days: 3, calendar: cal)   // 25, 26, 27 missed; 28 pending
        ctx.makeAsNeeded(iron, today: now, calendar: cal)
        ctx.syncSupplementLogs(today: now, days: 3, calendar: cal)
        #expect(iron.schedules.isEmpty)
        #expect(iron.logs.map(\.status).sorted { $0.rawValue < $1.rawValue } == [.missed, .missed, .missed])
    }

    @Test func takingAVitaminTicksTheOpenDoseBeforeJournaling() throws {
        let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
        let vitaminD = Supplement(name: "Vitamin D")
        ctx.insert(vitaminD)
        let daily = SupplementSchedule(startDate: date("2026-10-20", cal))
        ctx.insert(daily)
        daily.supplement = vitaminD
        ctx.syncSupplementLogs(today: now, days: 0, calendar: cal)
        #expect(ctx.takeVitamin(vitaminD, at: now, now: now, calendar: cal))           // ticks today's scheduled dose
        #expect(vitaminD.logs.map(\.status) == [.taken] && !vitaminD.logs[0].isJournal)
        #expect(ctx.takeVitamin(vitaminD, at: now, now: now + 5, calendar: cal))       // nothing open: journaled as extra
        #expect(vitaminD.logs.filter(\.isJournal).count == 1)
        #expect(!ctx.takeVitamin(vitaminD, at: now, now: now + 5.5, calendar: cal))    // double log ignored
    }

    @Test func aJournaledVitaminStartsTracking() throws {
        let ctx = ModelContext(try Persistence.makeContainer(inMemory: true))
        let c = Supplement(name: "Vitamin C")
        ctx.insert(c)
        ctx.logVitamin(c, at: now, now: now, calendar: cal)
        #expect(ctx.trackingStart(calendar: cal) == date("2026-10-28", cal))
    }
}
