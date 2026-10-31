import Charts
import SwiftData
import SwiftUI

struct TrendsView: View {
    @Environment(\.modelContext) private var context
    @Environment(HealthStore.self) private var health
    @Query private var settingsRows: [AppSettings]
    @Query private var meals: [Meal]          // observed so charts refresh after logging
    @Query private var water: [WaterEntry]
    @State private var days = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Period", selection: $days) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .pickerStyle(.segmented)
                    let _ = (meals.count, water.count)
                    ForEach(TrendSeries.all(days: days, context: context, health: health.snapshot,
                                            goals: settingsRows.first?.goals ?? Goals())) { MetricChart(series: $0) }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trends")
            .refreshable { await health.refresh() }
        }
    }
}

struct MetricSeries: Identifiable {
    enum Style { case bar, line, point }

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
            Text(series.title).font(.headline)
            Text(series.resolvedSummary).font(.subheadline).foregroundStyle(.secondary)
            if series.points.isEmpty {
                Text("No data in this period yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Chart {
                    if let band = series.band {
                        RectangleMark(yStart: .value("From", band.lowerBound), yEnd: .value("To", band.upperBound))
                            .foregroundStyle(.green.opacity(0.12))
                    }
                    ForEach(series.points, id: \.date) { p in
                        if series.style == .bar {
                            BarMark(x: .value("Day", p.date, unit: .day), y: .value(series.unit, p.value))
                                .foregroundStyle(.tint)
                        } else if series.style == .line {
                            LineMark(x: .value("Day", p.date, unit: .day), y: .value(series.unit, p.value))
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Day", p.date, unit: .day), y: .value(series.unit, p.value))
                                .symbolSize(series.points.count > 40 ? 8 : 24)
                        } else {
                            PointMark(x: .value("Day", p.date, unit: .day), y: .value(series.unit, p.value))
                        }
                    }
                    if let target = series.target {
                        RuleMark(y: .value(series.targetLabel, target))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.secondary)
                            .annotation(position: .top, alignment: .leading) {
                                Text(series.targetLabel).font(.caption2).foregroundStyle(.secondary)
                            }
                    }
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: 160)
                .accessibilityLabel("\(series.title). \(series.resolvedSummary)")
            }
            if let note = series.note { Text(note).font(.caption).foregroundStyle(.secondary) }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}

@MainActor
enum TrendSeries {
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
        let tracked = context.trackingStart(calendar: calendar).map { DayKey.of($0, calendar: calendar) } ?? DayKey.of(today, calendar: calendar)
        func habit(_ value: (DayRecord) -> Double?) -> [String: Double] {
            var out: [String: Double] = [:]
            for r in records {
                let key = DayKey.of(r.day, calendar: calendar)
                if key >= tracked, let v = value(r) { out[key] = v * 100 }
            }
            return out
        }
        let water = habit { BehaviorScore.ratio($0.facts.waterML, goals.waterTargetML) }
        let mealsOnTime = habit { MealRoutine.consistency($0.facts.mealTimings.values) }
        let supplements = habit { SupplementAdherence.rate($0.facts.supplementStatuses) }
        let energy = Dictionary(records.compactMap { r in r.energy.map { (DayKey.of(r.day, calendar: calendar), Double($0)) } },
                                uniquingKeysWith: { a, _ in a })
        let steps = health.steps.mapValues(Double.init)

        // Workouts per week (week start → count).
        var weekly: [Date: Double] = [:]
        for w in health.workouts where w.start >= prevStart {
            let weekStart = WeeklyReview.week(containing: w.start, calendar: calendar).start
            weekly[weekStart, default: 0] += 1
        }
        let workoutPoints = weekly.filter { $0.key >= WeeklyReview.week(containing: start, calendar: calendar).start }
            .sorted { $0.key < $1.key }.map { (date: $0.key, value: $0.value) }
        let percent: (Double) -> String = { "\(Int($0.rounded()))%" }

        return [
            MetricSeries(title: "Sleep duration", unit: "Hours", points: inRange(asleep), previous: previous(asleep),
                         target: Double(goals.sleepTargetMinutes) / 60, format: { Format.duration($0 * 3600) }),
            MetricSeries(title: "Bedtime consistency", unit: "Minutes from target", points: inRange(bedDeviation), style: .point,
                         target: 0, targetLabel: goals.bedtime.formatted(), band: -tolerance...tolerance,
                         summary: onTarget(bedDeviation), note: "Above the line = later than your target bedtime."),
            MetricSeries(title: "Wake-time consistency", unit: "Minutes from target", points: inRange(wakeDeviation), style: .point,
                         target: 0, targetLabel: goals.wakeTime.formatted(), band: -tolerance...tolerance,
                         summary: onTarget(wakeDeviation)),
            MetricSeries(title: "HRV", unit: "ms", points: inRange(health.hrv), previous: previous(health.hrv), style: .line,
                         target: inRange(health.hrv).map(\.value).mean, targetLabel: "Your average",
                         format: { "\(Int($0.rounded())) ms" }, note: "Compare with your own baseline, not with other people."),
            MetricSeries(title: "Resting heart rate", unit: "bpm", points: inRange(health.restingHR), previous: previous(health.restingHR),
                         style: .line, target: inRange(health.restingHR).map(\.value).mean, targetLabel: "Your average",
                         format: { "\(Int($0.rounded())) bpm" }),
            MetricSeries(title: "Deep sleep", unit: "Minutes", points: inRange(deep), previous: previous(deep),
                         format: { Format.duration($0 * 60) }, note: "Stages are estimates from your watch."),
            MetricSeries(title: "REM sleep", unit: "Minutes", points: inRange(rem), previous: previous(rem),
                         format: { Format.duration($0 * 60) }),
            MetricSeries(title: "Steps", unit: "Steps", points: inRange(steps), previous: previous(steps),
                         target: Double(goals.stepTarget), format: { Int($0).formatted() }),
            MetricSeries(title: "Workouts per week", unit: "Workouts", points: workoutPoints,
                         target: Double(goals.workoutsPerWeek), format: { Format.number($0, digits: 1) }),
            MetricSeries(title: "Water target", unit: "% of target", points: inRange(water), previous: previous(water),
                         target: 100, format: percent),
            MetricSeries(title: "Meals on time", unit: "% on time", points: inRange(mealsOnTime), previous: previous(mealsOnTime),
                         target: 100, format: percent),
            MetricSeries(title: "Supplements taken", unit: "% taken", points: inRange(supplements), previous: previous(supplements),
                         target: 100, format: percent),
            MetricSeries(title: "Energy", unit: "1–5", points: inRange(energy), previous: previous(energy), style: .line,
                         format: { Format.number($0, digits: 1) }),
        ]
    }
}
