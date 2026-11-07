import Charts
import SwiftData
import SwiftUI

struct TrendsView: View {
    @Environment(\.modelContext) private var context
    @Environment(HealthStore.self) private var health
    @Query private var settingsRows: [AppSettings]
    @Query private var meals: [Meal]          // observed so trends refresh after logging
    @Query private var water: [WaterEntry]
    @State private var days = 30

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Picker("Period", selection: $days) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    let _ = (meals.count, water.count)
                    let series = TrendSeries.all(days: days, context: context, health: health.snapshot,
                                                 goals: settingsRows.first?.goals ?? Goals())
                    let focus = TrendSeries.bodyPartCounts(days: days, context: context)
                    ForEach(MetricSeries.Group.allCases, id: \.self) { group in
                        Section {
                            ForEach(series.filter { $0.group == group }) { s in
                                NavigationLink {
                                    ScrollView { MetricChart(series: s).padding() }
                                        .appScreen()
                                        .navigationTitle(s.title)
                                        .navigationBarTitleDisplayMode(.inline)
                                } label: {
                                    TrendRow(series: s)
                                }
                            }
                            if group == .activity {
                                NavigationLink {
                                    BodyPartFocusView(counts: focus, days: days)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Body part focus")
                                        Text(BodyPartFocusView.summary(focus)).font(.caption).foregroundStyle(Palette.secondary)
                                    }
                                }
                            }
                        } header: { Header(group.rawValue) }
                    }
                }
                .appRows()
            }
            .appScreen()
            .navigationTitle("Trends")
            .refreshable { await health.refresh() }
        }
    }
}

/// One line per metric: name, summary and a tiny sparkline. Tap for the full chart.
struct TrendRow: View {
    let series: MetricSeries

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(series.title).foregroundStyle(Palette.text)
                Text(series.resolvedSummary).font(.caption).foregroundStyle(Palette.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            if series.points.count >= 2 {
                Chart(series.points, id: \.date) { p in
                    LineMark(x: .value("Day", p.date), y: .value(series.unit, p.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Palette.lime)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(width: 72, height: 30)
                .accessibilityHidden(true)
            }
        }
    }
}

struct MetricSeries: Identifiable {
    enum Style { case bar, line, point }
    enum Group: String, CaseIterable { case sleep = "Sleep", recovery = "Recovery", activity = "Activity", habits = "Habits" }

    var group: Group
    var title: String
    var unit: String
    var points: [(date: Date, value: Double)]
    var previous: [Double] = []
    var style: Style = .bar
    var target: Double?
    var targetLabel = "Target"
    /// Shaded "on target" band (bedtime/wake deviation).
    var band: ClosedRange<Double>?
    var format: (Double) -> String = { Format.number($0) }
    /// Overrides the default "average · change" summary.
    var summary: String?
    var note: String?

    var id: String { title }

    var resolvedSummary: String {
        if let summary { return summary }
        guard let avg = points.map(\.value).mean else { return "No data" }
        var text = "Avg \(format(avg))"
        if let change = Trend.percentChange(current: points.map(\.value), previous: previous) {
            let pct = Int((change * 100).rounded())
            text += pct == 0 ? " · same as before" : " · \(pct > 0 ? "↑" : "↓") \(abs(pct))% vs previous"
        }
        return text
    }
}

struct MetricChart: View {
    let series: MetricSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(series.title).font(.headline.weight(.regular)).foregroundStyle(Palette.text)
            Text(series.resolvedSummary).font(.subheadline).foregroundStyle(Palette.secondary)
            if series.points.isEmpty {
                Text("No data in this period yet.")
                    .font(.subheadline).foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Chart {
                    if let band = series.band {
                        RectangleMark(yStart: .value("From", band.lowerBound), yEnd: .value("To", band.upperBound))
                            .foregroundStyle(Palette.teal.opacity(0.16))
                    }
                    ForEach(series.points, id: \.date) { p in
                        if series.style == .bar {
                            BarMark(x: .value("Day", p.date, unit: .day), y: .value(series.unit, p.value))
                                .foregroundStyle(LinearGradient(colors: [Palette.lime, Palette.limeDeep.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                                .cornerRadius(3)
                        } else if series.style == .line {
                            AreaMark(x: .value("Day", p.date, unit: .day), y: .value(series.unit, p.value))
                                .interpolationMethod(.monotone)
                                .foregroundStyle(LinearGradient(colors: [Palette.lime.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("Day", p.date, unit: .day), y: .value(series.unit, p.value))
                                .interpolationMethod(.monotone)
                                .foregroundStyle(Palette.lime)
                            PointMark(x: .value("Day", p.date, unit: .day), y: .value(series.unit, p.value))
                                .symbolSize(series.points.count > 40 ? 8 : 24)
                                .foregroundStyle(Palette.lime)
                        } else {
                            PointMark(x: .value("Day", p.date, unit: .day), y: .value(series.unit, p.value))
                                .foregroundStyle(Palette.lime)
                        }
                    }
                    if let target = series.target {
                        RuleMark(y: .value(series.targetLabel, target))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(Palette.text.opacity(0.5))
                            .annotation(position: .top, alignment: .leading) {
                                Text(series.targetLabel).font(.caption2).foregroundStyle(Palette.secondary)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Palette.track)
                        AxisValueLabel().foregroundStyle(Palette.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Palette.track)
                        AxisValueLabel().foregroundStyle(Palette.secondary)
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("\(series.title). \(series.resolvedSummary)")
            }
            if let note = series.note { Text(note).font(.caption).foregroundStyle(Palette.secondary) }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

@MainActor
enum TrendSeries {
    static func bodyPartCounts(days: Int, context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> [BodyPart: Int] {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: 1 - days, to: today) ?? today
        return context.gymSessions(from: DayKey.of(start, calendar: calendar), through: DayKey.of(today, calendar: calendar))
            .flatMap(\.focus).reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    static func all(days: Int, context: ModelContext, health: HealthSnapshot, goals: Goals,
                    now: Date = .now, calendar: Calendar = .current) -> [MetricSeries] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: 1 - days, to: today),
              let prevStart = calendar.date(byAdding: .day, value: -days, to: start) else { return [] }
        let startKey = DayKey.of(start, calendar: calendar), prevStartKey = DayKey.of(prevStart, calendar: calendar)
        func date(_ key: String) -> Date { DayKey.date(key, calendar: calendar) ?? today }
        func inRange(_ values: [String: Double]) -> [(date: Date, value: Double)] {
            values.filter { $0.key >= startKey }.sorted { $0.key < $1.key }.map { (date($0.key), $0.value) }
        }
        func previous(_ values: [String: Double]) -> [Double] {
            values.filter { $0.key >= prevStartKey && $0.key < startKey }.map(\.value)
        }

        let nights = health.nights(calendar: calendar)
        let asleep = nights.mapValues { $0.asleep / 3600 }
        let deep = nights.compactMapValues { $0.deep.map { $0 / 60 } }
        let rem = nights.compactMapValues { $0.rem.map { $0 / 60 } }
        let bedDeviation = nights.mapValues { Double(goals.bedtime.signedMinutes(to: TimeOfDay(of: $0.sleepStart, in: calendar))) }
        let wakeDeviation = nights.mapValues { Double(goals.wakeTime.signedMinutes(to: TimeOfDay(of: $0.finalWake, in: calendar))) }
        let tolerance = Double(goals.sleepToleranceMinutes)
        func onTarget(_ deviations: [String: Double]) -> String {
            let current = deviations.filter { $0.key >= startKey }
            guard !current.isEmpty else { return "No data" }
            return "On target \(current.values.filter { abs($0) <= tolerance }.count) of \(current.count) nights"
        }

        // Manual habits only count from the first day anything was logged.
        let records = context.dayRecords(from: prevStart, through: today, health: health, goals: goals, now: now, calendar: calendar)
        let tracked = context.trackingStart(calendar: calendar).map { DayKey.of($0, calendar: calendar) }
        func habit(_ value: (DayRecord) -> Double?) -> [String: Double] {
            var out: [String: Double] = [:]
            for r in records {
                let key = DayKey.of(r.day, calendar: calendar)
                if let tracked, key >= tracked, let v = value(r) { out[key] = v * 100 }
            }
            return out
        }
        let water = habit { $0.facts.waterML.flatMap { BehaviorScore.ratio($0, goals.waterTargetML) } }
        let mealsOnTime = habit { MealRoutine.consistency($0.facts.mealTimings.values) }
        let supplements = habit { SupplementAdherence.rate($0.facts.supplementStatuses) }
        let energy = Dictionary(records.compactMap { r in r.energy.map { (DayKey.of(r.day, calendar: calendar), Double($0)) } },
                                uniquingKeysWith: { a, _ in a })
        let steps = health.steps.mapValues(Double.init)

        // Workouts per week (week start → count): watch or journal, never both for one day.
        var weekly: [Date: Double] = [:]
        for r in records where r.workouts > 0 {
            weekly[WeeklyReview.week(containing: r.day, calendar: calendar).start, default: 0] += Double(r.workouts)
        }
        let protein = Dictionary(records.compactMap { r in r.protein.map { (DayKey.of(r.day, calendar: calendar), Double($0)) } },
                                 uniquingKeysWith: +)
        let workoutPoints = weekly.filter { $0.key >= WeeklyReview.week(containing: start, calendar: calendar).start }
            .sorted { $0.key < $1.key }.map { (date: $0.key, value: $0.value) }
        let percent: (Double) -> String = { "\(Int($0.rounded()))%" }
        // Your usual range over the period (median ± MAD), drawn as a band instead of a plain average line.
        let hrvRange = UsualRange(inRange(health.hrv).map(\.value))
        let restingRange = UsualRange(inRange(health.restingHR).map(\.value))

        return [
            MetricSeries(group: .sleep, title: "Sleep duration", unit: "Hours", points: inRange(asleep), previous: previous(asleep),
                         target: Double(goals.sleepTargetMinutes) / 60, format: { Format.duration($0 * 3600) }),
            MetricSeries(group: .sleep, title: "Bedtime consistency", unit: "Minutes from target", points: inRange(bedDeviation), style: .point,
                         target: 0, targetLabel: goals.bedtime.formatted(), band: -tolerance...tolerance,
                         summary: onTarget(bedDeviation), note: "Above the line = later than your target bedtime."),
            MetricSeries(group: .sleep, title: "Wake-time consistency", unit: "Minutes from target", points: inRange(wakeDeviation), style: .point,
                         target: 0, targetLabel: goals.wakeTime.formatted(), band: -tolerance...tolerance,
                         summary: onTarget(wakeDeviation)),
            MetricSeries(group: .recovery, title: "HRV", unit: "ms", points: inRange(health.hrv), previous: previous(health.hrv), style: .line,
                         target: hrvRange?.median, targetLabel: "Your usual", band: hrvRange.map { $0.low...$0.high },
                         format: { "\(Int($0.rounded())) ms" }, note: "The band is your usual range. Compare with yourself, not with other people."),
            MetricSeries(group: .recovery, title: "Resting heart rate", unit: "bpm", points: inRange(health.restingHR), previous: previous(health.restingHR),
                         style: .line, target: restingRange?.median, targetLabel: "Your usual", band: restingRange.map { $0.low...$0.high },
                         format: { "\(Int($0.rounded())) bpm" }),
            MetricSeries(group: .sleep, title: "Deep sleep", unit: "Minutes", points: inRange(deep), previous: previous(deep),
                         format: { Format.duration($0 * 60) }, note: "Stages are estimates from your watch."),
            MetricSeries(group: .sleep, title: "REM sleep", unit: "Minutes", points: inRange(rem), previous: previous(rem),
                         format: { Format.duration($0 * 60) }),
            MetricSeries(group: .activity, title: "Steps", unit: "Steps", points: inRange(steps), previous: previous(steps),
                         target: Double(goals.stepTarget), format: { Int($0).formatted() }),
            MetricSeries(group: .activity, title: "Workouts per week", unit: "Workouts", points: workoutPoints,
                         target: Double(goals.workoutsPerWeek), format: { Format.number($0, digits: 1) }),
            MetricSeries(group: .habits, title: "Water target", unit: "% of target", points: inRange(water), previous: previous(water),
                         target: 100, format: percent),
            MetricSeries(group: .habits, title: "Protein", unit: "g", points: inRange(protein), previous: previous(protein),
                         target: Double(goals.proteinTargetGrams), format: { "\(Int($0.rounded())) g" }),
            MetricSeries(group: .habits, title: "Meals on time", unit: "% on time", points: inRange(mealsOnTime), previous: previous(mealsOnTime),
                         target: 100, format: percent),
            MetricSeries(group: .habits, title: "Vitamins taken", unit: "% taken", points: inRange(supplements), previous: previous(supplements),
                         target: 100, format: percent),
            MetricSeries(group: .habits, title: "Energy", unit: "1–5", points: inRange(energy), previous: previous(energy), style: .line,
                         format: { Format.number($0, digits: 1) }),
        ]
    }
}
