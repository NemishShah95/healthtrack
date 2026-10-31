import SwiftData
import SwiftUI

// Full pages behind the Today tiles. Each works for any of the last few days.

private func title(_ base: String, _ day: Date) -> String {
    Calendar.current.isDateInToday(day) ? base : "\(base) · \(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))"
}

struct ConsistencyDetail: View {
    @Environment(\.modelContext) private var context
    @Environment(HealthStore.self) private var health
    @Query private var settingsRows: [AppSettings]
    let day: Date

    var body: some View {
        let goals = settingsRows.first?.goals ?? Goals()
        let record = context.dayRecords(from: day, through: day, health: health.snapshot, goals: goals).first
        let c = record.map { BehaviorScore.components($0.facts, goals: goals) } ?? [:]
        List {
            Section {
                HStack {
                    Spacer()
                    Ring(value: BehaviorScore.score(c), size: 120, lineWidth: 12)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section {
                ForEach(ScoreComponent.allCases, id: \.self) { component in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(component.title)
                            Spacer()
                            Text(c[component] == nil ? "No data" : Format.percent(c[component]))
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        if let v = c[component] { ProgressView(value: v) }
                        Text(Self.explain(component, goals)).font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } footer: {
                Text("Did I do what I intended? Habits only, never a medical score. Areas with no data are left out instead of counting as zero.")
            }
        }
        .navigationTitle(title("Consistency", day))
    }

    static func explain(_ c: ScoreComponent, _ g: Goals) -> String {
        switch c {
        case .sleep: "Bedtime and wake within ±\(g.sleepToleranceMinutes) min, and \(Format.duration(Double(g.sleepTargetMinutes * 60))) asleep. Weight 25%."
        case .meals: "Breakfast, lunch and dinner inside their windows. Off-window counts half. Weight 20%."
        case .exercise: "Workouts in the last 7 days vs \(g.workoutsPerWeek) a week. Weight 20%."
        case .hydration: "Water vs \(String(format: "%.1f", Double(g.waterTargetML) / 1000)) L a day. Weight 15%."
        case .supplements: "Scheduled doses taken. Weight 10%."
        case .movement: "Steps vs \(g.stepTarget.formatted()). Weight 10%."
        }
    }
}

struct SleepDetail: View {
    @Environment(HealthStore.self) private var health
    @Query private var settingsRows: [AppSettings]
    let day: Date

    var body: some View {
        let goals = settingsRows.first?.goals ?? Goals()
        let key = DayKey.of(day, calendar: .current)
        let s = health.snapshot
        let night = s.nights(calendar: .current)[key]
        List {
            if let n = night {
                let bed = TimeOfDay(of: n.sleepStart, in: .current)
                let wake = TimeOfDay(of: n.finalWake, in: .current)
                Section {
                    LabeledContent("Asleep", value: Format.duration(n.asleep))
                    target("Fell asleep", bed, goals.isBedtimeOnTarget(bed), goals.bedtime)
                    target("Woke", wake, goals.isWakeOnTarget(wake), goals.wakeTime)
                    LabeledContent("In bed", value: Format.duration(n.inBed))
                    LabeledContent("Awake", value: Format.duration(n.awake))
                    LabeledContent("Interruptions", value: "\(n.interruptions)")
                }
                Section {
                    LabeledContent("Core", value: n.core.map(Format.duration) ?? "—")
                    LabeledContent("Deep", value: n.deep.map(Format.duration) ?? "—")
                    LabeledContent("REM", value: n.rem.map(Format.duration) ?? "—")
                } header: {
                    Text("Stages")
                } footer: {
                    Text(n.deep == nil ? "Your watch didn't record sleep stages this night."
                                       : "Stages are estimates from your watch. More or less of a stage isn't automatically better or worse.")
                }
            } else {
                ContentUnavailableView("No sleep recorded", systemImage: "bed.double",
                                       description: Text("Wear your watch to bed. Zepp syncs sleep to Apple Health."))
            }
            Section {
                LabeledContent("HRV", value: s.hrv[key].map { "\(Int($0.rounded())) ms" } ?? "—")
                LabeledContent("Resting heart rate", value: s.restingHR[key].map { "\(Int($0.rounded())) bpm" } ?? "—")
                if let line = baselineLine(s.hrv, key: key, name: "HRV") { Text(line).font(.footnote).foregroundStyle(.secondary) }
                if let line = baselineLine(s.restingHR, key: key, name: "Resting heart rate") { Text(line).font(.footnote).foregroundStyle(.secondary) }
            } header: {
                Text("Recovery")
            } footer: {
                Text("Compared with your own 30-day average. Not a diagnosis.")
            }
        }
        .navigationTitle(title("Sleep", day))
    }

    private func target(_ label: String, _ t: TimeOfDay, _ ok: Bool, _ goal: TimeOfDay) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
                Text(t.formatted())
            }
            .foregroundStyle(ok ? Palette.good : Palette.warn)
        }
        .accessibilityValue("\(t.formatted()), target \(goal.formatted()), \(ok ? "on target" : "off target")")
    }

    private func baselineLine(_ values: [String: Double], key: String, name: String) -> String? {
        guard let value = values[key],
              let start = Calendar.current.date(byAdding: .day, value: -30, to: day) else { return nil }
        let startKey = DayKey.of(start, calendar: .current)
        guard let base = values.filter({ $0.key >= startKey && $0.key < key }).map(\.value).mean, base > 0 else { return nil }
        let pct = Int(((value - base) / base * 100).rounded())
        return pct == 0 ? "\(name) is at your 30-day average." : "\(name) is \(abs(pct))% \(pct > 0 ? "above" : "below") your 30-day average."
    }
}

struct WaterDetail: View {
    @Environment(\.modelContext) private var context
    @Query private var water: [WaterEntry]
    @Query private var settingsRows: [AppSettings]
    let day: Date

    init(day: Date) {
        self.day = day
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        _water = Query(filter: #Predicate<WaterEntry> { $0.timestamp >= day && $0.timestamp < end },
                       sort: \.timestamp, order: .reverse)
    }

    var body: some View {
        let target = settingsRows.first?.goals.waterTargetML ?? Goals().waterTargetML
        let total = water.reduce(0) { $0 + $1.amountML }
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Hydration.progressText(totalML: total, targetML: target))
                        .font(.largeTitle.bold().monospacedDigit())
                        .contentTransition(.numericText())
                    ProgressView(value: min(1, Double(total) / Double(max(target, 1)))).tint(.blue)
                }
                WaterButtons(day: day)
            }
            Section("Entries") {
                if water.isEmpty { Text("Nothing yet.").foregroundStyle(.secondary) }
                ForEach(water) { entry in
                    LabeledContent("\(entry.amountML) ml", value: entry.timestamp.formatted(date: .omitted, time: .shortened))
                }
                .onDelete { for i in $0 { context.delete(water[i]) } }
            }
        }
        .navigationTitle(title("Water", day))
    }
}

struct ProteinDetail: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [ProteinEntry]
    @Query private var settingsRows: [AppSettings]
    let day: Date

    init(day: Date) {
        self.day = day
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        _entries = Query(filter: #Predicate<ProteinEntry> { $0.timestamp >= day && $0.timestamp < end },
                         sort: \.timestamp, order: .reverse)
    }

    var body: some View {
        let target = settingsRows.first?.goals.proteinTargetGrams ?? Goals().proteinTargetGrams
        let total = entries.reduce(0) { $0 + $1.grams }
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(total) / \(target) g").font(.largeTitle.bold().monospacedDigit()).contentTransition(.numericText())
                    ProgressView(value: min(1, Double(total) / Double(max(target, 1)))).tint(.pink)
                }
                ProteinButtons(day: day)
            } footer: {
                Text("Your own target, set in Settings → Goals. HealthTrack doesn't recommend an intake.")
            }
            Section("Entries") {
                if entries.isEmpty { Text("Nothing yet.").foregroundStyle(.secondary) }
                ForEach(entries) { e in
                    LabeledContent(e.label.isEmpty ? "\(e.grams) g" : "\(e.grams) g · \(e.label)",
                                   value: e.timestamp.formatted(date: .omitted, time: .shortened))
                }
                .onDelete { for i in $0 { context.delete(entries[i]) } }
            }
        }
        .navigationTitle(title("Protein", day))
    }
}

struct SupplementsDetail: View {
    @Environment(\.modelContext) private var context
    @Query private var doses: [SupplementLog]
    let day: Date
    let key: String

    init(day: Date) {
        let key = DayKey.of(day, calendar: .current)
        self.day = day
        self.key = key
        _doses = Query(filter: #Predicate<SupplementLog> { $0.day == key })
    }

    var body: some View {
        let isPast = !Calendar.current.isDateInToday(day)
        let _ = doses.map(\.statusRaw)
        let sorted = context.supplementLogs(from: key, through: key)
        List {
            Section {
                if sorted.isEmpty { Text("Nothing scheduled.").foregroundStyle(.secondary) }
                ForEach(sorted) { DoseRow(log: $0, isPast: isPast) }
                if sorted.contains(where: { $0.status == .pending || $0.status == .missed }) {
                    Button("Mark all taken", systemImage: "checkmark.circle") { context.markAllTaken(onDay: key) }
                }
            } footer: {
                if isPast { Text("Forgot to tick something? You can fix it here for up to five days.") }
            }
            Section {
                NavigationLink("Manage supplements") { SupplementsView() }
            }
        }
        .navigationTitle(title("Supplements", day))
    }
}

struct ActivityDetail: View {
    @Environment(\.modelContext) private var context
    @Environment(HealthStore.self) private var health
    @Query private var settingsRows: [AppSettings]
    let day: Date

    var body: some View {
        let goals = settingsRows.first?.goals ?? Goals()
        let key = DayKey.of(day, calendar: .current)
        let s = health.snapshot
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        let todays = s.workouts.filter { $0.start >= day && $0.start < end }
        List {
            Section("Steps") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(s.steps[key].map { $0.formatted() } ?? "—").font(.largeTitle.bold().monospacedDigit())
                    ProgressView(value: min(1, Double(s.steps[key] ?? 0) / Double(max(goals.stepTarget, 1)))).tint(.green)
                    Text("Target \(goals.stepTarget.formatted())").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Workouts") {
                if todays.isEmpty { Text("No workouts.").foregroundStyle(.secondary) }
                ForEach(Array(todays.enumerated()), id: \.offset) { _, w in
                    LabeledContent(w.activityName) {
                        Text([Format.duration(w.duration), w.activeEnergyKcal.map { "≈ \(Int($0)) kcal" }].compactMap { $0 }.joined(separator: " · "))
                    }
                }
                LabeledContent("This week", value: "\(context.workoutsThisWeek(containing: day, health: s, goals: goals)) / \(goals.workoutsPerWeek)")
            }
            Section {
                LabeledContent("Active energy", value: s.activeEnergy[key].map { "≈ \(Int($0)) kcal" } ?? "—")
            } footer: {
                Text("Calories are estimates from your watch, not exact measurements.")
            }
        }
        .navigationTitle(title("Activity", day))
    }
}

struct CheckInDetail: View {
    let day: Date

    var body: some View {
        let key = DayKey.of(day, calendar: .current)
        Form {
            Section {
                CheckInControls(dayKey: key)
            } footer: {
                Text("1 = low, 5 = high. Tap a selected number again to clear it.")
            }
            Section("Notes") {
                CheckInNotes(dayKey: key)
            }
        }
        .navigationTitle(title("Check-in", day))
    }
}
