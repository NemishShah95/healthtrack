import Foundation
import SwiftData

/// Realistic manual logs for the simulator (`-seedSampleData`). Never runs on its own on the iPhone.
@MainActor
enum SampleData {
    static func seedIfEmpty(_ ctx: ModelContext, days: Int = 90, now: Date = .now, calendar: Calendar = .current) {
        guard ((try? ctx.fetchCount(FetchDescriptor<Meal>())) ?? 0) == 0 else { return }
        var rng = SplitMix64(seed: 42)
        let today = calendar.startOfDay(for: now)
        guard let first = calendar.date(byAdding: .day, value: 1 - days, to: today) else { return }

        let supplements: [(String, String, [Int], DayPart)] = [
            ("Vitamin D", "1000 IU", [], .morning), ("Vitamin B complex", "1 tablet", [], .morning),
            ("Vitamin C", "500 mg", [], .morning), ("Iron", "1 tablet", [2, 4, 6], .afternoon),
            ("Magnesium glycinate", "200 mg", [], .evening),
        ]
        for (name, dose, weekdays, part) in supplements {
            let s = Supplement(name: name, dosageText: dose)
            s.createdAt = first
            ctx.insert(s)
            let schedule = SupplementSchedule(daysOfWeek: weekdays, preferredTime: part, startDate: first)
            ctx.insert(schedule)
            schedule.supplement = s
        }

        let breakfasts = ["oats 80 g\nbanana 120 g\nyogurt 150 g", "eggs 120 g\ntoast 60 g", "poha 200 g", "smoothie 300 g"]
        let lunches = ["rice 180 g\ndal 200 g\nsalad 100 g", "chicken wrap 250 g", "quinoa bowl 320 g", "roti 80 g\npaneer 150 g"]
        let dinners = ["salmon 150 g\nvegetables 200 g", "pasta 220 g", "khichdi 300 g", "chicken curry 250 g\nrice 150 g"]

        var day = first
        while day <= today {
            let isToday = day == today
            func at(_ hour: Int, _ minute: Int, spread: Int) -> Date {
                TimeOfDay(hour, minute + Int.random(in: -spread...spread, using: &rng)).on(day, in: calendar)
            }
            func maybeFoods(_ options: [String]) -> [ParsedFood] {
                let r = Double.random(in: 0...1, using: &rng)
                return r < 0.3 ? [] : MealRoutine.parseFoods(options.randomElement(using: &rng)!)  // 30% quick logs
            }
            if Double.random(in: 0...1, using: &rng) < 0.9 { ctx.logMeal(.breakfast, foods: maybeFoods(breakfasts), at: at(8, 15, spread: 70), calendar: calendar) }
            if !isToday, Double.random(in: 0...1, using: &rng) < 0.85 { ctx.logMeal(.lunch, foods: maybeFoods(lunches), at: at(13, 0, spread: 60), calendar: calendar) }
            if !isToday, Double.random(in: 0...1, using: &rng) < 0.9 { ctx.logMeal(.dinner, foods: maybeFoods(dinners), at: at(20, 0, spread: 80), calendar: calendar) }

            for i in 0..<(isToday ? 3 : Int.random(in: 5...10, using: &rng)) {
                let entry = WaterEntry(amountML: [250, 250, 500].randomElement(using: &rng)!, at: at(8 + i * 2, 0, spread: 40), createdAt: day)
                ctx.insert(entry)
            }
            // Push / pull / legs / cardio rotation, about four sessions a week.
            let weekday = calendar.component(.weekday, from: day)
            let plan: [Int: ([BodyPart], String)] = [
                2: ([.chest, .shoulders, .arms], "Bench press 4x8 60 kg\nOverhead press 3x10 35 kg\nTricep dips 3x12"),
                3: ([.back, .arms], "Deadlift 3x5 100 kg\nLat pulldown 3x10 50 kg\nBicep curl 3x12 12 kg"),
                5: ([.legs, .glutes, .core], "Squat 4x6 90 kg\nRomanian deadlift 3x10 60 kg\nPlank 3x1"),
                6: ([.fullBody], "Treadmill 25 min 4 km\nRowing 10 min 2 km"),
            ]
            if let (focus, lines) = plan[weekday], !isToday, Double.random(in: 0...1, using: &rng) < 0.85 {
                ctx.logGym(focus: focus, exercises: GymLog.parse(lines), at: at(18, 30, spread: 45), calendar: calendar)
            }
            for i in 0..<(isToday ? 1 : Int.random(in: 2...4, using: &rng)) {
                let entry = ProteinEntry(grams: [20, 25, 30, 35].randomElement(using: &rng)!, label: ["", "whey shake", "eggs", "paneer"].randomElement(using: &rng)!,
                                         at: at(9 + i * 4, 0, spread: 60), createdAt: day)
                ctx.insert(entry)
            }
            if !isToday, Double.random(in: 0...1, using: &rng) < 0.8 {
                let c = ctx.checkIn(onDay: DayKey.of(day, calendar: calendar))
                c.energy = Int.random(in: 2...5, using: &rng)
                c.mood = Int.random(in: 2...5, using: &rng)
                c.stress = Int.random(in: 1...4, using: &rng)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        ctx.syncSupplementLogs(today: now, days: days - 1, calendar: calendar)
        let todayKey = DayKey.of(now, calendar: calendar)
        for log in (try? ctx.fetch(FetchDescriptor<SupplementLog>())) ?? [] where log.day < todayKey {
            if Double.random(in: 0...1, using: &rng) < 0.88 { ctx.setStatus(.taken, for: log, at: now) }
        }
        let saved = SavedMeal(name: "Usual breakfast", type: .breakfast, foodLines: breakfasts[0])
        ctx.insert(saved)
        ctx.settings().favoriteFoods = ["oats", "banana", "yogurt", "rice", "dal"]
        try? ctx.save()
    }
}
