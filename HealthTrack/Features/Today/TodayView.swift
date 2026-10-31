import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.scenePhase) private var scenePhase
    @State private var day = Calendar.current.startOfDay(for: .now)

    var body: some View {
        NavigationStack {
            TodayDashboard(day: day)
                .id(day)
                .navigationTitle("Today")
                .refreshable { await health.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { day = Calendar.current.startOfDay(for: .now) }   // rolls over after midnight
        }
    }
}

private struct TodayDashboard: View {
    @Environment(\.modelContext) private var context
    @Environment(HealthStore.self) private var health
    @Query private var meals: [Meal]
    @Query private var water: [WaterEntry]
    @Query private var doses: [SupplementLog]
    @Query private var checkIns: [DailyCheckIn]
    @Query private var settingsRows: [AppSettings]
    let day: Date
    let key: String

    init(day: Date) {
        let key = DayKey.of(day, calendar: .current)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        self.day = day
        self.key = key
        _meals = Query(filter: #Predicate<Meal> { $0.day == key }, sort: \.timestamp)
        _water = Query(filter: #Predicate<WaterEntry> { $0.timestamp >= day && $0.timestamp < end }, sort: \.timestamp)
        _doses = Query(filter: #Predicate<SupplementLog> { $0.day == key })
        _checkIns = Query(filter: #Predicate<DailyCheckIn> { $0.day == key })
    }

    var body: some View {
        let settings = settingsRows.first
        let goals = settings?.goals ?? Goals()
        let _ = checkIns.first?.updatedAt   // re-render on check-in changes
        let record = context.dayRecords(from: day, through: day, health: health.snapshot, goals: goals).first
        let components = record.map { BehaviorScore.components($0.facts, goals: goals) } ?? [:]
        let snapshot = health.snapshot

        ScrollView {
            VStack(spacing: 16) {
                if let settings { RefreshBanner(status: ReinstallTracker.status(settings)) }
                ConsistencyCard(components: components)
                SleepCard(night: snapshot.nights(calendar: .current)[key], hrv: snapshot.hrv[key],
                          hrvBaseline: baseline(snapshot.hrv), restingHR: snapshot.restingHR[key],
                          restingBaseline: baseline(snapshot.restingHR), goals: goals, access: health.access)
                MealsCard(timings: record?.facts.mealTimings ?? [:], windows: goals.mealWindows, meals: meals,
                          consistency: components[.meals])
                WaterCard(totalML: water.reduce(0) { $0 + $1.amountML }, targetML: goals.waterTargetML, latest: water.last)
                SupplementsCard(doses: context.supplementLogs(from: key, through: key), dayKey: key)
                ActivityCard(day: day, steps: snapshot.steps[key], energy: snapshot.activeEnergy[key],
                             workouts: snapshot.workouts, goals: goals)
                Card(title: "Check-in", systemImage: "face.smiling", tint: .teal) {
                    CheckInControls(dayKey: key)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) { if health.isLoading && snapshot.steps.isEmpty { ProgressView().padding() } }
        .onAppear { _ = doses.count }
    }

    /// Mean of the previous 30 days, excluding today.
    private func baseline(_ values: [String: Double]) -> Double? {
        guard let start = Calendar.current.date(byAdding: .day, value: -30, to: day) else { return nil }
        let startKey = DayKey.of(start, calendar: .current)
        return values.filter { $0.key >= startKey && $0.key < key }.map(\.value).mean
    }
}

private struct ConsistencyCard: View {
    let components: [ScoreComponent: Double]

    var body: some View {
        Card(title: "Daily consistency", systemImage: "checkmark.seal.fill", tint: .green) {
            if let score = BehaviorScore.score(components) {
                Text(Format.percent(score))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .accessibilityLabel("Daily consistency \(Format.percent(score))")
                ForEach(ScoreComponent.allCases.filter { components[$0] != nil }, id: \.self) { c in
                    HStack {
                        Text(c.title).font(.subheadline)
                        Spacer()
                        ProgressView(value: components[c] ?? 0).frame(width: 90).tint(.green)
                        Text(Format.percent(components[c])).font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text("Log something to see how today is going.").foregroundStyle(.secondary)
            }
            Text("Did I do what I intended today? This is about habits, not a medical score.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct SleepCard: View {
    let night: NightSummary?
    let hrv: Double?
    let hrvBaseline: Double?
    let restingHR: Double?
    let restingBaseline: Double?
    let goals: Goals
    let access: HealthAccess

    var body: some View {
        Card(title: "Sleep", systemImage: "bed.double.fill", tint: .indigo) {
            if let n = night {
                let bed = TimeOfDay(of: n.sleepStart, in: .current)
                let wake = TimeOfDay(of: n.finalWake, in: .current)
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.duration(n.asleep)).font(.largeTitle.bold().monospacedDigit())
                    Text("asleep").foregroundStyle(.secondary)
                }
                HStack {
                    target("Bedtime", bed, onTarget: goals.isBedtimeOnTarget(bed))
                    target("Woke", wake, onTarget: goals.isWakeOnTarget(wake))
                }
                HStack {
                    Stat(label: "Deep", value: n.deep.map(Format.duration) ?? "—")
                    Stat(label: "REM", value: n.rem.map(Format.duration) ?? "—")
                    Stat(label: "Awake", value: Format.duration(n.awake))
                }
            } else {
                Text(access == .notRequested ? "Connect Apple Health in Settings to see sleep."
                                             : "No sleep recorded for last night.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Stat(label: "HRV", value: hrv.map { "\(Int($0.rounded())) ms" } ?? "—")
                Stat(label: "Resting HR", value: restingHR.map { "\(Int($0.rounded())) bpm" } ?? "—")
            }
            if let line = baselineLine { Text(line).font(.caption).foregroundStyle(.secondary) }
            if night?.deep != nil {
                Text("Sleep stages are estimates from your watch.").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private var baselineLine: String? {
        guard let hrv, let hrvBaseline, hrvBaseline > 0 else { return nil }
        let pct = Int(((hrv - hrvBaseline) / hrvBaseline * 100).rounded())
        return pct == 0 ? "HRV is at your 30-day average." : "HRV is \(abs(pct))% \(pct > 0 ? "above" : "below") your 30-day average."
    }

    private func target(_ label: String, _ time: TimeOfDay, onTarget: Bool) -> some View {
        Label("\(label) \(time.formatted())", systemImage: onTarget ? "checkmark.circle.fill" : "exclamationmark.circle")
            .font(.subheadline)
            .foregroundStyle(onTarget ? .green : .orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("\(label) \(time.formatted()), \(onTarget ? "on target" : "off target")")
    }
}

private struct MealsCard: View {
    @Environment(\.modelContext) private var context
    let timings: [MealType: MealTiming]
    let windows: [MealType: MealWindow]
    let meals: [Meal]
    let consistency: Double?

    var body: some View {
        Card(title: "Meals", systemImage: "fork.knife", tint: .orange) {
            ForEach(MealType.targeted, id: \.self) { type in
                let timing = timings[type] ?? .pending
                HStack {
                    Image(systemName: timing.symbol).foregroundStyle(timing.color)
                    Text(type.rawValue.capitalized)
                    Spacer()
                    if let meal = meals.first(where: { $0.mealType == type }) {
                        Text("\(meal.localTime.formatted()) · \(timing.label)").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        if timing == .pending, let w = windows[type] {
                            Text("by \(w.end.formatted())").font(.caption).foregroundStyle(.secondary)
                        }
                        Button("Log now") { context.logMeal(type) }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            let snacks = meals.filter { $0.mealType == .snack || $0.mealType == .custom }.count
            if snacks > 0 { Text("\(snacks) snack\(snacks == 1 ? "" : "s") logged").font(.caption).foregroundStyle(.secondary) }
            if let consistency { Text("Meal routine \(Format.percent(consistency))").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct WaterCard: View {
    @Environment(\.modelContext) private var context
    let totalML: Int
    let targetML: Int
    let latest: WaterEntry?

    var body: some View {
        Card(title: "Water", systemImage: "drop.fill", tint: .blue) {
            HStack(alignment: .firstTextBaseline) {
                Text(Hydration.progressText(totalML: totalML, targetML: targetML))
                    .font(.title2.bold().monospacedDigit())
                    .contentTransition(.numericText())
                Spacer()
                if let latest {
                    Button("Undo", systemImage: "arrow.uturn.backward") { context.delete(latest) }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Remove the last \(latest.amountML) millilitres")
                }
            }
            ProgressView(value: min(1, Double(totalML) / Double(max(targetML, 1)))).tint(.blue)
            WaterButtons()
        }
    }
}

private struct SupplementsCard: View {
    @Environment(\.modelContext) private var context
    let doses: [SupplementLog]
    let dayKey: String

    var body: some View {
        Card(title: "Supplements", systemImage: "pills.fill", tint: .purple) {
            if doses.isEmpty {
                Text("Nothing scheduled today.").foregroundStyle(.secondary)
                NavigationLink("Manage supplements") { SupplementsView() }.font(.subheadline)
            } else {
                ForEach(doses) { DoseRow(log: $0) }
                if doses.contains(where: { $0.status == .pending }) {
                    Button("Mark all taken", systemImage: "checkmark.circle") { context.markAllTaken(onDay: dayKey) }
                        .buttonStyle(.bordered).tint(.purple)
                }
            }
        }
    }
}

private struct ActivityCard: View {
    let day: Date
    let steps: Int?
    let energy: Double?
    let workouts: [WorkoutSummary]
    let goals: Goals

    var body: some View {
        let cal = Calendar.current
        let dayEnd = cal.date(byAdding: .day, value: 1, to: day) ?? day
        let today = workouts.filter { $0.start >= day && $0.start < dayEnd }
        let week = WeeklyReview.week(containing: day, calendar: cal)
        let thisWeek = workouts.filter { week.contains($0.start) }.count

        Card(title: "Activity", systemImage: "figure.walk", tint: .green) {
            if steps == nil && workouts.isEmpty {
                Text("No activity data from Apple Health yet.").foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text((steps ?? 0).formatted()).font(.title2.bold().monospacedDigit())
                    Text("/ \(goals.stepTarget.formatted()) steps").foregroundStyle(.secondary)
                }
                ProgressView(value: min(1, Double(steps ?? 0) / Double(max(goals.stepTarget, 1)))).tint(.green)
                ForEach(Array(today.enumerated()), id: \.offset) { _, w in
                    Label("\(w.activityName) · \(Format.duration(w.duration))", systemImage: "figure.run").font(.subheadline)
                }
                HStack {
                    Stat(label: "Workouts this week", value: "\(thisWeek) / \(goals.workoutsPerWeek)")
                    Stat(label: "Active energy", value: energy.map { "≈ \(Int($0)) kcal" } ?? "—")
                }
            }
        }
    }
}
