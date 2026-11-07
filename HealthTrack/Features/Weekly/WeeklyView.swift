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
        // The current week only counts finished days, so this morning's untaken doses don't drag it down.
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: .now)) ?? .now
        let lastDay = offset == 0 ? max(week.start, min(week.end.addingTimeInterval(-1), yesterday)) : week.end.addingTimeInterval(-1)
        let _ = meals.count
        let tracked = context.trackingStart(calendar: cal) ?? cal.startOfDay(for: .now)
        let records = context.dayRecords(from: max(week.start, tracked), through: lastDay, health: health.snapshot, goals: goals)
        let previousRecords = context.dayRecords(from: previous.start, through: previous.end.addingTimeInterval(-1),
                                                 health: health.snapshot, goals: goals)
        let r = WeeklyReview(weekStart: week.start, days: records, previousWeek: previousRecords, goals: goals)

        List {
            Group {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Week of \(week.start.formatted(.dateTime.month(.abbreviated).day()))\(offset == 0 && r.days > 0 ? " · so far" : "")".uppercased())
                            .font(.caption.bold()).foregroundStyle(Palette.secondary)
                        HStack(spacing: 16) {
                            Ring(value: r.consistency, size: 84, lineWidth: 10)
                            VStack(alignment: .leading, spacing: 6) {
                                if let best = r.bestHabit {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Image(systemName: "star.fill").foregroundStyle(Palette.good).accessibilityHidden(true)
                                        Text("Best: \(best.title)").fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                if !r.needsAttention.isEmpty {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Image(systemName: "eye").foregroundStyle(Palette.warn).accessibilityHidden(true)
                                        Text("Watch: \(r.needsAttention.map(\.title).joined(separator: ", "))").fixedSize(horizontal: false, vertical: true)
                                    }
                                } else if r.days > 0 {
                                    Label("Nothing needs attention", systemImage: "checkmark").foregroundStyle(Palette.secondary)
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(Palette.text)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if r.days == 0 {
                    ContentUnavailableView("Nothing logged this week", systemImage: "calendar",
                                           description: Text("Your review fills in as you log."))
                } else {
                    Section {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                            GridRow {
                                Stat(label: "Sleep", value: r.averageSleepMinutes.map { Format.duration($0 * 60) } ?? "—")
                                Stat(label: "Meals on time", value: Format.percent(r.mealsOnTimeRate))
                            }
                            GridRow {
                                Stat(label: "Workouts", value: "\(r.workouts) / \(r.workoutTarget)")
                                Stat(label: "Water target", value: "\(r.waterTargetDays) / \(r.days) days")
                            }
                            GridRow {
                                Stat(label: "Protein", value: r.averageProtein.map { "\(Int($0.rounded())) g avg" } ?? "—")
                                Stat(label: "Gym sessions", value: "\(r.gymSessions)")
                            }
                        }
                        .padding(.vertical, 4)
                        NavigationLink("Full breakdown") { WeeklyBreakdown(review: r) }
                    }
                    if let experiment = r.experiment {
                        Section {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "flask.fill").foregroundStyle(Palette.lime).accessibilityHidden(true)
                                Text(experiment).foregroundStyle(Palette.text).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("Try this next week")
                        } footer: {
                            Text("One small experiment, aimed at your weakest habit this week. A suggestion about habits, not medical advice.")
                        }
                    }
                }
                InsightsSection()
            }
            .appRows()
        }
        .appScreen()
    }
}

/// Every weekly number, one tap away from the summary.
private struct WeeklyBreakdown: View {
    let review: WeeklyReview

    var body: some View {
        let r = review
        List {
            Group {
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
                Section("Gym") {
                    LabeledContent("Sessions journaled", value: "\(r.gymSessions)")
                    LabeledContent("Trained", value: r.bodyParts.isEmpty ? "—"
                        : BodyPart.allCases.compactMap { p in r.bodyParts[p].map { "\(p.title) \($0)" } }.joined(separator: " · "))
                }
                Section("Protein") {
                    LabeledContent("Average", value: r.averageProtein.map { "\(Int($0.rounded())) g" } ?? "—")
                    LabeledContent("Target reached", value: "\(r.proteinTargetDays) / \(r.proteinDaysLogged) logged days")
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
            }
            .appRows()
        }
        .appScreen()
        .navigationTitle("Week of \(r.weekStart.formatted(.dateTime.month(.abbreviated).day()))")
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
                    .foregroundStyle(Palette.secondary)
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

        let logs = context.supplementLogs(from: startKey, through: todayKey).filter { $0.day < todayKey && !$0.isJournal }
        for (name, group) in Dictionary(grouping: logs, by: { $0.supplement?.name ?? "" }) where !name.isEmpty {
            if let i = Insights.supplementLogged(name: name, taken: group.filter { $0.status == .taken }.count, scheduled: group.count) {
                out.append(i)
            }
        }
        return out
    }
}
