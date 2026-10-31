import Foundation
import SwiftData

/// Joins manual logs (SwiftData) with Health data into one `DayRecord` per day.
@MainActor
extension ModelContext {
    func checkIns(from startKey: String, through endKey: String) -> [DailyCheckIn] {
        let d = FetchDescriptor<DailyCheckIn>(predicate: #Predicate { $0.day >= startKey && $0.day <= endKey })
        return (try? fetch(d)) ?? []
    }

    /// The first day with any manual log. Earlier days have no manual facts, so they aren't scored
    /// as "skipped meals" or "no water".
    func trackingStart(calendar: Calendar = .current) -> Date? {
        var meal = FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.timestamp)])
        meal.fetchLimit = 1
        var water = FetchDescriptor<WaterEntry>(sortBy: [SortDescriptor(\.timestamp)])
        water.fetchLimit = 1
        let firsts = [try? fetch(meal).first?.timestamp, try? fetch(water).first?.timestamp].compactMap { $0 }
        return firsts.min().map { calendar.startOfDay(for: $0) }
    }

    /// Workouts so far in the calendar week containing `day` (watch or journal, never both for one day).
    func workoutsThisWeek(containing day: Date, health: HealthSnapshot, goals: Goals,
                          now: Date = .now, calendar: Calendar = .current) -> Int {
        let week = WeeklyReview.week(containing: day, calendar: calendar)
        return dayRecords(from: week.start, through: week.end.addingTimeInterval(-1), health: health, goals: goals,
                          now: now, calendar: calendar).reduce(0) { $0 + $1.workouts }
    }

    /// Days from `start` through `end` (inclusive, clipped to today), oldest first.
    func dayRecords(from start: Date, through end: Date, health: HealthSnapshot, goals: Goals,
                    now: Date = .now, calendar: Calendar = .current) -> [DayRecord] {
        var days: [Date] = []
        var day = calendar.startOfDay(for: start)
        let last = min(calendar.startOfDay(for: end), calendar.startOfDay(for: now))
        while day <= last {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        guard let first = days.first, let lastDay = days.last,
              let afterLast = calendar.date(byAdding: .day, value: 1, to: lastDay) else { return [] }

        let firstKey = DayKey.of(first, calendar: calendar), lastKey = DayKey.of(lastDay, calendar: calendar)
        let todayKey = DayKey.of(now, calendar: calendar)
        let startKey = trackingStart(calendar: calendar).map { DayKey.of($0, calendar: calendar) } ?? todayKey
        let meals = Dictionary(grouping: meals(from: firstKey, through: lastKey), by: \.day)
        let water = Dictionary(grouping: water(from: first, to: afterLast)) { DayKey.of($0.timestamp, calendar: calendar) }
        let doses = Dictionary(grouping: supplementLogs(from: firstKey, through: lastKey), by: \.day)
        let checkIns = Dictionary(checkIns(from: firstKey, through: lastKey).map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        let nights = health.nights(calendar: calendar)
        let protein = Dictionary(grouping: protein(from: first, to: afterLast)) { DayKey.of($0.timestamp, calendar: calendar) }
        let weekBefore = calendar.date(byAdding: .day, value: -6, to: first) ?? first
        let gym = Dictionary(grouping: gymSessions(from: DayKey.of(weekBefore, calendar: calendar), through: lastKey), by: \.day)
        // HealthKit never says whether reading was denied. No steps, no workouts and no journaled sessions
        // means "no access", so exercise is left out rather than scored as zero.
        let hasActivityData = !health.steps.isEmpty || !health.workouts.isEmpty || !gym.isEmpty
        /// The larger of watch workouts and journaled sessions, so one gym visit never counts twice.
        func workouts(on day: Date) -> Int {
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return max(health.workouts.filter { $0.start >= day && $0.start < end }.count,
                       gym[DayKey.of(day, calendar: calendar)]?.count ?? 0)
        }

        return days.map { day in
            let key = DayKey.of(day, calendar: calendar)
            var f = DayFacts()
            if let n = nights[key] {
                f.bedtime = TimeOfDay(of: n.sleepStart, in: calendar)
                f.wakeTime = TimeOfDay(of: n.finalWake, in: calendar)
                f.asleepMinutes = n.asleep / 60
            }
            if key >= startKey {
                let dayMeals = meals[key] ?? []
                let nowTime = key == todayKey ? TimeOfDay(of: now, in: calendar) : nil
                for type in MealType.targeted {
                    guard let window = goals.mealWindows[type] else { continue }
                    f.mealTimings[type] = MealRoutine.timing(loggedTimes: dayMeals.filter { $0.mealType == type }.map(\.localTime),
                                                            window: window, now: nowTime)
                }
                f.waterML = (water[key] ?? []).reduce(0) { $0 + $1.amountML }
            }
            f.supplementStatuses = (doses[key] ?? []).map {
                SupplementAdherence.resolved($0.status, scheduledDay: day, today: now, calendar: calendar)
            }
            f.steps = health.steps[key]
            if hasActivityData {
                f.workoutsInLast7Days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: day) }.map(workouts).reduce(0, +)
            }
            let sessions = gym[key] ?? []
            return DayRecord(day: day, facts: f, hrv: health.hrv[key], restingHR: health.restingHR[key],
                             energy: checkIns[key]?.energy, workouts: workouts(on: day),
                             protein: protein[key].map { $0.reduce(0) { $0 + $1.grams } },
                             gymSessions: sessions.count, bodyParts: sessions.flatMap(\.focus))
        }
    }
}
