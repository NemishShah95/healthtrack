import SwiftData
import SwiftUI

struct WeeklyView: View {
    @State private var offset = 0   // 0 = this week, -1 = last week …

    var body: some View {
        NavigationStack {
            WeeklyContent(offset: offset)
                .navigationTitle("Weekly")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Previous week", systemImage: "chevron.left") { offset -= 1 }
                        Button("Next week", systemImage: "chevron.right") { offset += 1 }.disabled(offset >= 0)
                    }
                }
        }
    }
}

private struct WeeklyContent: View {
    @Environment(\.modelContext) private var context
    @Environment(HealthStore.self) private var health
    @Query private var settingsRows: [AppSettings]
    @Query private var meals: [Meal]
    let offset: Int

    var body: some View {
        let cal = Calendar.current
        let goals = settingsRows.first?.goals ?? Goals()
        let anchor = cal.date(byAdding: .weekOfYear, value: offset, to: .now) ?? .now
        let week = WeeklyReview.week(containing: anchor, calendar: cal)
        let previous = WeeklyReview.week(containing: week.start.addingTimeInterval(-86_400), calendar: cal)
        let lastDay = week.end.addingTimeInterval(-1)
        let _ = meals.count
        let tracked = context.trackingStart(calendar: cal) ?? cal.startOfDay(for: .now)
        let records = context.dayRecords(from: max(week.start, tracked), through: lastDay, health: health.snapshot, goals: goals)
        let previousRecords = context.dayRecords(from: previous.start, through: previous.end.addingTimeInterval(-1),
                                                 health: health.snapshot, goals: goals)
        let r = WeeklyReview(weekStart: week.start, days: records, previousWeek: previousRecords, goals: goals)

        List {
            Section {
                VStack(alignment: .leading) {
                    Text("Week of \(week.start.formatted(.dateTime.month(.abbreviated).day()))".uppercased())
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Text(Format.percent(r.consistency)).font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    Text("Consistency").foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            if r.days == 0 {
                ContentUnavailableView("Nothing logged this week", systemImage: "calendar",
                                       description: Text("Your review fills in as you log."))
            } else {
                Section("Sleep") {
                    LabeledContent("Average", value: r.averageSleepMinutes.map { Format.duration($0 * 60) } ?? "—")
                    LabeledContent("Bedtime target", value: "\(r.bedtimeHits) / \(r.nightsWithSleep)")
                    LabeledContent("Wake target", value: "\(r.wakeHits) / \(r.nightsWithSleep)")
                    LabeledContent("HRV trend", value: trend(r.hrvTrend))
                    LabeledContent("Resting HR", value: trend(r.restingHRTrend))
                }
                Section("Food") {
                    LabeledContent("Meals on time", value: Format.percent(r.mealsOnTimeRate))
                    LabeledContent("Late dinners", value: "\(r.lateDinners)")
                    LabeledContent("Meals logged", value: "\(r.mealsLogged) / \(r.mealsEvaluated)")
                }
                Section("Exercise") {
                    LabeledContent("Workouts", value: "\(r.workouts) / \(r.workoutTarget)")
                    LabeledContent("Steps", value: r.averageSteps.map { "\(Int($0).formatted()) avg" } ?? "—")
                }
                Section("Water") {
                    LabeledContent("Target achieved", value: "\(r.waterTargetDays) / \(r.days)")
                }
                Section("Supplements") {
                    LabeledContent("Adherence", value: Format.percent(r.supplementAdherence))
                }
                Section("Energy") {
                    LabeledContent("Average", value: r.averageEnergy.map { "\(Format.number($0, digits: 1)) / 5" } ?? "—")
                }
                Section("Best habit") {
                    Text(r.bestHabit?.title ?? "—")
                }
                Section("Needs attention") {
                    if r.needsAttention.isEmpty { Text("Nothing stands out. Nice week.") }
                    ForEach(r.needsAttention, id: \.self) { Text($0.title) }
                }
            }
            InsightsSection()
        }
    }

    private func trend(_ t: TrendDirection?) -> String {
        switch t {
        case .up: "↑ Up"
        case .down: "↓ Down"
        case .stable: "Stable"
        case nil: "Not enough data"
        }
    }
}

/// Descriptive observations over the last 30 days. Associations only, never causes.
private struct InsightsSection: View {
    @Environment(\.modelContext) private var context
    @Environment(HealthStore.self) private var health

    var body: some View {
        let insights = Self.build(context: context, health: health.snapshot, goals: context.settings().goals)
        Section {
            if insights.isEmpty {
                Text("Observations appear once there's enough data, usually after a few weeks of logging.")
                    .foregroundStyle(.secondary)
            }
            ForEach(insights, id: \.text) { Text($0.text) }
        } header: {
            Text("Observations")
        } footer: {
            Text("Patterns in your own data, not causes or medical advice.")
        }
    }

    static func build(context: ModelContext, health: HealthSnapshot, goals: Goals,
                      now: Date = .now, calendar: Calendar = .current) -> [Insight] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -30, to: today),
              let priorStart = calendar.date(byAdding: .day, value: -60, to: today) else { return [] }
        let startKey = DayKey.of(start, calendar: calendar), priorKey = DayKey.of(priorStart, calendar: calendar)
        let todayKey = DayKey.of(today, calendar: calendar)
        let nights = health.nights(calendar: calendar)
        var out: [Insight] = []

        // Dinner on day D vs the night that ends on D+1.
        let dinners = Dictionary(context.meals(from: startKey, through: todayKey).filter { $0.mealType == .dinner }.map { ($0.day, $0.localTime) },
                                 uniquingKeysWith: min)
        let pairs: [(dinner: TimeOfDay, asleepMinutes: Double)] = dinners.compactMap { day, time in
            guard let d = DayKey.date(day, calendar: calendar),
                  let next = calendar.date(byAdding: .day, value: 1, to: d),
                  let night = nights[DayKey.of(next, calendar: calendar)] else { return nil }
            return (time, night.asleep / 60)
        }
        if let i = Insights.sleepVsDinnerTime(pairs) { out.append(i) }

        let hrv = health.hrv
        if let i = Insights.hrvChange(last30: hrv.filter { $0.key >= startKey }.map(\.value),
                                      prior30: hrv.filter { $0.key >= priorKey && $0.key < startKey }.map(\.value)) {
            out.append(i)
        }

        let recentNights = nights.filter { $0.key >= startKey }.values
        let hits = recentNights.filter { goals.isBedtimeOnTarget(TimeOfDay(of: $0.sleepStart, in: calendar)) }.count
        if let i = Insights.bedtimeTargetRate(hits: hits, nights: recentNights.count, period: "in the last 30 days") { out.append(i) }

        let logs = context.supplementLogs(from: startKey, through: todayKey).filter { $0.day < todayKey }
        for (name, group) in Dictionary(grouping: logs, by: { $0.supplement?.name ?? "" }) where !name.isEmpty {
            if let i = Insights.supplementLogged(name: name, taken: group.filter { $0.status == .taken }.count, scheduled: group.count) {
                out.append(i)
            }
        }
        return out
    }
}
