import Charts
import SwiftData
import SwiftUI

/// Today plus the previous six days. Swipe or tap a day in the week strip to see, fix or back-fill it.
struct TodayView: View {
    static let daysBack = 6

    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Calendar.current.startOfDay(for: .now)
    @State private var selection = TodayView.daysBack   // last page = today
    @State private var path: [DayRoute] = []

    private var days: [Date] {
        (0...Self.daysBack).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                WeekStrip(days: days, selection: $selection)
                TabView(selection: $selection) {
                    ForEach(Array(days.enumerated()), id: \.element) { i, day in
                        DayDashboard(day: day, isToday: i == Self.daysBack) { path.append($0) }
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(AppBackground())
            .navigationTitle(Self.title(for: days[min(selection, days.count - 1)]))
            .navigationDestination(for: DayRoute.self) { $0.destination }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let now = Calendar.current.startOfDay(for: .now)
            if now != today {   // rolled past midnight while in the background
                today = now
                selection = Self.daysBack
                path = []
            }
        }
    }

    static func title(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide))
    }
}

/// Detail pages reachable from the cards.
enum DayRoute: Hashable {
    case consistency(Date), sleep(Date), meals(Date), water(Date), supplements(Date), activity(Date), checkIn(Date)
    case protein(Date), gym(Date)

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .consistency(let day): ConsistencyDetail(day: day)
        case .sleep(let day): SleepDetail(day: day)
        case .meals(let day): MealsDetail(day: day)
        case .water(let day): WaterDetail(day: day)
        case .supplements(let day): SupplementsDetail(day: day)
        case .activity(let day): ActivityDetail(day: day)
        case .checkIn(let day): CheckInDetail(day: day)
        case .protein(let day): ProteinDetail(day: day)
        case .gym(let day): GymDetail(day: day)
        }
    }
}

// MARK: - Week strip

/// S M T W T F S with a small bar per day: lime when the day's consistency reached 70%, dim when it started,
/// grey with no data. The selected day is circled.
private struct WeekStrip: View {
    @Environment(\.modelContext) private var context
    @Environment(HealthStore.self) private var health
    @Query private var settingsRows: [AppSettings]
    // Observed so the bars update the moment something is logged.
    @Query private var meals: [Meal]
    @Query private var water: [WaterEntry]
    @Query private var doses: [SupplementLog]
    @Query private var gym: [GymSession]
    @Query private var checkIns: [DailyCheckIn]
    let days: [Date]
    @Binding var selection: Int

    var body: some View {
        let goals = settingsRows.first?.goals ?? Goals()
        let _ = (meals.count, water.count, doses.map(\.statusRaw), gym.count, checkIns.map(\.updatedAt))
        let records = context.dayRecords(from: days[0], through: days[days.count - 1], health: health.snapshot, goals: goals)
        let scores = Dictionary(records.map { (Calendar.current.startOfDay(for: $0.day), BehaviorScore.score(BehaviorScore.components($0.facts, goals: goals))) },
                                uniquingKeysWith: { a, _ in a })
        HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.element) { i, day in
                let selected = i == selection
                let score = scores[day] ?? nil
                Button {
                    withAnimation { selection = i }
                } label: {
                    VStack(spacing: 8) {
                        Capsule()
                            .fill(score.map { $0 >= WeeklyReview.attentionThreshold ? Palette.lime : Palette.lime.opacity(0.35) } ?? Palette.track)
                            .frame(width: 18, height: 4)
                        Text(Calendar.current.veryShortWeekdaySymbols[Calendar.current.component(.weekday, from: day) - 1])
                            .font(.subheadline)
                            .foregroundStyle(selected ? Palette.text : Palette.secondary)
                            .frame(minWidth: 36, minHeight: 36)
                            .overlay(Circle().strokeBorder(selected ? Palette.text.opacity(0.6) : .clear, lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(TodayView.title(for: day)), \(day.formatted(date: .complete, time: .omitted))")
                .accessibilityValue(score.map { "Consistency \(Format.percent($0))" } ?? "No data")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}

// MARK: - One day

private struct DayDashboard: View {
    @Environment(\.modelContext) private var context
    @Environment(HealthStore.self) private var health
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var meals: [Meal]
    @Query private var water: [WaterEntry]
    @Query private var doses: [SupplementLog]
    @Query private var checkIns: [DailyCheckIn]
    @Query private var settingsRows: [AppSettings]
    @Query private var supplements: [Supplement]
    @Query private var protein: [ProteinEntry]
    @Query private var gym: [GymSession]
    @State private var editing: MealEditor.Target?
    @State private var editingGym: GymEditor.Target?
    @State private var addingVitamin = false
    @State private var loggingVitamin = false
    let day: Date
    let key: String
    let isToday: Bool
    let open: (DayRoute) -> Void

    init(day: Date, isToday: Bool, open: @escaping (DayRoute) -> Void) {
        let key = DayKey.of(day, calendar: .current)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        self.day = day
        self.key = key
        self.isToday = isToday
        self.open = open
        _meals = Query(filter: #Predicate<Meal> { $0.day == key }, sort: \.timestamp)
        _water = Query(filter: #Predicate<WaterEntry> { $0.timestamp >= day && $0.timestamp < end })
        _doses = Query(filter: #Predicate<SupplementLog> { $0.day == key })
        _checkIns = Query(filter: #Predicate<DailyCheckIn> { $0.day == key })
        _protein = Query(filter: #Predicate<ProteinEntry> { $0.timestamp >= day && $0.timestamp < end })
        _gym = Query(filter: #Predicate<GymSession> { $0.day == key }, sort: \.timestamp)
    }

    var body: some View {
        let goals = settingsRows.first?.goals ?? Goals()
        let _ = doses.map(\.statusRaw)   // reading these re-renders on every tick
        let record = context.dayRecords(from: day, through: day, health: health.snapshot, goals: goals).first
        let components = record.map { BehaviorScore.components($0.facts, goals: goals) } ?? [:]
        let large = typeSize.isAccessibilitySize
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: large ? 1 : 2)

        ScrollView {
            VStack(spacing: 12) {
                if isToday {
                    if let settings = settingsRows.first { RefreshBanner(status: ReinstallTracker.status(settings)) }
                    SyncStatus(snapshot: health.snapshot, access: health.access)
                }
                hero(goals: goals, components: components, large: large)
                LazyVGrid(columns: columns, spacing: 12) {
                    waterTile(goals: goals)
                    mealsTile(timings: record?.facts.mealTimings ?? [:], goals: goals)
                    proteinTile(goals: goals)
                    vitaminsTile()
                    recoveryTile()
                    checkInTile(checkIns.first)
                }
                workoutsCard()
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable { await health.refresh() }
        .sheet(item: $editing) { MealEditor(target: $0) }
        .sheet(item: $editingGym) { GymEditor(target: $0) }
        .sheet(isPresented: $addingVitamin) { SupplementEditor(supplement: nil) }
        .sheet(isPresented: $loggingVitamin) { VitaminLogSheet(day: day) }
    }

    // MARK: Hero: sleep | steps + consistency

    @ViewBuilder
    private func hero(goals: Goals, components: [ScoreComponent: Double], large: Bool) -> some View {
        let sleep = SleepCard(night: health.snapshot.nights(calendar: .current)[key], goals: goals) { open(.sleep(day)) }
        let steps = StepsCard(steps: health.snapshot.steps[key], target: goals.stepTarget,
                              workouts: context.workoutsThisWeek(containing: day, health: health.snapshot, goals: goals),
                              workoutTarget: goals.workoutsPerWeek) { open(.activity(day)) }
        let ring = ConsistencyCard(components: components) { open(.consistency(day)) }
        if large {
            VStack(spacing: 12) { sleep; steps; ring }
        } else {
            HStack(alignment: .top, spacing: 12) {
                sleep.frame(maxHeight: .infinity)
                VStack(spacing: 12) { steps; ring }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Habit tiles

    private func waterTile(goals: Goals) -> some View {
        let total = water.reduce(0) { $0 + $1.amountML }
        return Tile(title: "Water", systemImage: "drop.fill", tint: Palette.water, open: { open(.water(day)) }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Hydration.progressText(totalML: total, targetML: goals.waterTargetML)).contentTransition(.numericText())
                ProgressBar(value: Double(total) / Double(max(goals.waterTargetML, 1)), tint: Palette.water)
            }
        } accessory: {
            PillButton(title: "+250", accessibilityLabel: "Add 250 millilitres") {
                context.logWater(250, at: Calendar.current.timestamp(on: day))
            }
        }
    }

    private func proteinTile(goals: Goals) -> some View {
        let total = protein.reduce(0) { $0 + $1.grams }
        return Tile(title: "Protein", systemImage: "fork.knife.circle.fill", tint: Palette.protein, open: { open(.protein(day)) }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(total) / \(goals.proteinTargetGrams) g").contentTransition(.numericText())
                ProgressBar(value: Double(total) / Double(max(goals.proteinTargetGrams, 1)), tint: Palette.protein)
            }
        } accessory: {
            PillButton(title: "+20 g", accessibilityLabel: "Add 20 grams of protein") {
                context.logProtein(20, at: Calendar.current.timestamp(on: day))
            }
        }
    }

    private func mealsTile(timings: [MealType: MealTiming], goals: Goals) -> some View {
        let logged = Set(meals.map(\.mealType))
        let next = MealRoutine.nextMeal(logged: logged, windows: goals.mealWindows,
                                        now: isToday ? TimeOfDay(of: .now, in: .current) : TimeOfDay(23, 59))
        return Tile(title: "Meals", systemImage: "fork.knife", tint: Palette.meals,
                    detail: next == nil ? "All logged" : nil, open: { open(.meals(day)) }) {
            HStack(spacing: 12) {
                ForEach(MealType.targeted, id: \.self) { type in
                    let timing = timings[type] ?? .pending
                    VStack(spacing: 4) {
                        Image(systemName: timing.symbol).font(.title3).foregroundStyle(timing.color)
                        Text(type.rawValue.prefix(1).uppercased()).font(.caption2).foregroundStyle(Palette.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(type.rawValue) \(timing.label)")
                }
            }
        } accessory: {
            if let next {
                PillButton(title: "+ \(next.rawValue.capitalized)", accessibilityLabel: "Log \(next.rawValue)") {
                    if isToday {
                        context.logMeal(next)
                    } else {
                        editing = .new(day: day, type: next)   // past day: pick the time
                    }
                }
            }
        }
    }

    /// Scheduled doses ("2/3"), plus journal entries logged on top ("+1 extra").
    private func vitaminsTile() -> some View {
        let scheduled = doses.filter { !$0.isJournal }.map(\.status)
        let extra = doses.filter(\.isJournal).count
        let taken = scheduled.filter { $0 == .taken }.count
        let outstanding = scheduled.contains { $0 == .pending || $0 == .missed }
        let detail: String? = scheduled.isEmpty ? nil : (extra > 0 ? "+\(extra) extra" : "taken")
        return Tile(title: "Vitamins", systemImage: "pills.fill", tint: Palette.vitamins, detail: detail,
                    open: { open(.supplements(day)) }) {
            if supplements.isEmpty {
                Placeholder("None added")
            } else if !scheduled.isEmpty {
                Text("\(taken)/\(scheduled.count)")
            } else if extra > 0 {
                Text("\(extra) taken")
            } else {
                Placeholder("None today")
            }
        } accessory: {
            if supplements.isEmpty {
                PillButton(title: "+ Add", accessibilityLabel: "Add a vitamin") { addingVitamin = true }
            } else if outstanding {
                PillButton(title: "All ✓", accessibilityLabel: "Mark all vitamins taken") {
                    context.markAllTaken(onDay: key)
                }
            } else {
                PillButton(title: "+ Log", accessibilityLabel: "Log a vitamin") { loggingVitamin = true }
            }
        }
    }

    /// HRV against your own usual range (median ± MAD of the 30 days before), resting HR as a fallback.
    private func recoveryTile() -> some View {
        let s = health.snapshot
        let (name, values, unit) = s.hrv[key] != nil || s.restingHR[key] == nil
            ? ("HRV", s.hrv, "ms") : ("Resting HR", s.restingHR, "bpm")
        let value = values[key]
        let range = UsualRange.before(key, in: values, calendar: .current)
        let detail: String? = value.map { v in
            guard let range else { return "Usual range after \(UsualRange.minDays) days" }
            switch range.position(of: v) {
            case .within: return "\(name) · usual"
            case .above: return "\(name) · above usual"
            case .below: return "\(name) · below usual"
            }
        }
        return Tile(title: "Recovery", systemImage: "waveform.path.ecg", tint: Palette.teal, detail: detail,
                    open: { open(.sleep(day)) }) {
            if let value { Text("\(Int(value.rounded())) \(unit)") } else { Placeholder("No data") }
        } accessory: { EmptyView() }
    }

    private func checkInTile(_ c: DailyCheckIn?) -> some View {
        let done = c?.energy != nil || c?.mood != nil || c?.stress != nil
        return Tile(title: "Check-in", systemImage: "face.smiling", tint: Palette.checkIn,
                    detail: done ? "Energy · Mood · Stress" : "Three taps", open: { open(.checkIn(day)) }) {
            if done {
                Text([c?.energy, c?.mood, c?.stress].map { $0.map(String.init) ?? "–" }.joined(separator: " · "))
            } else {
                Text("How are you?").font(.system(.title3, weight: .light))
            }
        } accessory: { EmptyView() }
    }

    // MARK: Workouts

    private func workoutsCard() -> some View {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        let watch = health.snapshot.workouts.filter { $0.start >= day && $0.start < end }
        var rows: [WorkoutRow.Model] = gym.map { s in
            .init(symbol: "dumbbell.fill", title: s.title,
                  subtitle: "\(s.timestamp.formatted(date: .omitted, time: .shortened)) · \(s.exercises.count) exercise\(s.exercises.count == 1 ? "" : "s")",
                  minutes: nil, time: s.timestamp)
        }
        rows += watch.map { w in
            .init(symbol: WorkoutRow.symbol(for: w.activityName), title: w.activityName,
                  subtitle: "\(w.start.formatted(date: .omitted, time: .shortened)) · from your watch",
                  minutes: Int((w.duration / 60).rounded()), time: w.start)
        }
        rows.sort { $0.time < $1.time }
        return ZStack(alignment: .topTrailing) {
            Button { open(.gym(day)) } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Workouts").font(.headline.weight(.regular)).foregroundStyle(Palette.text)
                        Spacer()
                    }
                    if rows.isEmpty {
                        Text("Nothing logged yet").font(.subheadline).foregroundStyle(Palette.secondary)
                    }
                    ForEach(rows) { WorkoutRow(model: $0) }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the gym journal")
            PillButton(title: "+ Log", accessibilityLabel: "Log a gym session") { editingGym = .new(day: day) }
                .padding(8)
        }
    }
}

// MARK: - Cards

/// Last night: big duration plus the stage chart (hypnogram).
private struct SleepCard: View {
    let night: NightSummary?
    let goals: Goals
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Sleep").font(.subheadline).foregroundStyle(Palette.secondary)
                    Spacer()
                    Image(systemName: "moon.stars.fill").foregroundStyle(Palette.teal)
                }
                if let night {
                    ValueText.duration(night.asleep, size: 40)
                } else {
                    Placeholder("No data").font(.system(.title, weight: .light))
                }
                Spacer(minLength: 8)
                if let night {
                    Hypnogram(night: night).frame(height: 110)
                    Text(notes(night)).font(.caption).foregroundStyle(Palette.secondary).lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(minHeight: 200)
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens sleep details")
    }

    private func notes(_ n: NightSummary) -> String {
        var notes: [String] = []
        let bed = goals.bedtime.signedMinutes(to: TimeOfDay(of: n.sleepStart, in: .current))
        let wake = goals.wakeTime.signedMinutes(to: TimeOfDay(of: n.finalWake, in: .current))
        if bed > goals.sleepToleranceMinutes { notes.append("Late to bed") }
        if bed < -goals.sleepToleranceMinutes { notes.append("Early to bed") }
        if abs(wake) > goals.sleepToleranceMinutes { notes.append(wake > 0 ? "Woke late" : "Woke early") }
        if n.asleep / 60 < Double(goals.sleepTargetMinutes) { notes.append("Short") }
        return notes.isEmpty ? "On target" : notes.prefix(2).joined(separator: " · ")
    }
}

/// Stage-by-time chart: awake at the top, deep at the bottom. Gaps between asleep samples are awake.
struct Hypnogram: View {
    let night: NightSummary

    struct Segment: Identifiable {
        let id: Int
        let start: Date
        let end: Date
        let level: Double
        let color: Color
    }

    var body: some View {
        Chart(Self.segments(night)) { s in
            RectangleMark(xStart: .value("Start", s.start), xEnd: .value("End", s.end),
                          yStart: .value("Stage", s.level - 0.36), yEnd: .value("Stage", s.level + 0.36))
                .foregroundStyle(s.color)
                .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: -0.5...3.5)
        .accessibilityHidden(true)
    }

    static func segments(_ n: NightSummary) -> [Segment] {
        func style(_ s: SleepStage) -> (Double, Color) {
            switch s {
            case .deep: (0, Palette.deep)
            case .core, .asleepUnspecified: (1, Palette.core)
            case .rem: (2, Palette.rem)
            case .awake, .inBed: (3, Palette.awake)
            }
        }
        var out: [Segment] = []
        var lastEnd: Date?
        for sample in n.samples {
            if let lastEnd, sample.start.timeIntervalSince(lastEnd) >= SleepAggregator.minInterruption {
                out.append(Segment(id: out.count, start: lastEnd, end: sample.start, level: 3, color: Palette.awake))
            }
            let (level, color) = style(sample.stage)
            out.append(Segment(id: out.count, start: sample.start, end: sample.end, level: level, color: color))
            lastEnd = max(lastEnd ?? sample.end, sample.end)
        }
        return out
    }
}

/// Steps with an orbit arc whose glowing dot travels with progress towards the target.
private struct StepsCard: View {
    let steps: Int?
    let target: Int
    let workouts: Int
    let workoutTarget: Int
    let open: () -> Void

    var body: some View {
        let progress = Double(steps ?? 0) / Double(max(target, 1))
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Steps").font(.subheadline).foregroundStyle(Palette.secondary)
                Spacer(minLength: 18)
                if let steps {
                    ValueText(steps.formatted(), unit: "steps", size: 30)
                } else {
                    Placeholder("No data").font(.system(.title2, weight: .light))
                }
                Text("\(workouts)/\(workoutTarget) workouts this week").font(.caption).foregroundStyle(Palette.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .background(alignment: .topTrailing) { Orbit(progress: min(1, progress)).accessibilityHidden(true) }
            .clipShape(.rect(cornerRadius: 26))
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens activity details")
    }
}

/// A quarter of a large circle in the card's top-right corner, with a glowing dot at `progress`.
private struct Orbit: View {
    let progress: Double
    private let radius: CGFloat = 96

    var body: some View {
        // Centre sits on the card's top-right corner; the visible quarter runs from the right edge to the top.
        // The dot travels 105°…165° so it never slips off the card.
        let angle = Angle.degrees(105 + 60 * progress)
        ZStack {
            Circle().stroke(Palette.lime.opacity(0.28), lineWidth: 1.2).frame(width: radius * 2, height: radius * 2)
            Circle().stroke(Palette.lime.opacity(0.10), lineWidth: 1).frame(width: radius * 2.7, height: radius * 2.7)
            Circle()
                .fill(Palette.lime)
                .frame(width: 9, height: 9)
                .shadow(color: Palette.lime, radius: 6)
                .overlay(Circle().stroke(Palette.lime.opacity(0.35), lineWidth: 6).frame(width: 20, height: 20))
                .offset(x: radius * cos(angle.radians), y: radius * sin(angle.radians))
        }
        .frame(width: 0, height: 0)
    }
}

/// The day's consistency ring.
private struct ConsistencyCard: View {
    let components: [ScoreComponent: Double]
    let open: () -> Void

    var body: some View {
        let score = BehaviorScore.score(components)
        let onTrack = components.values.filter { $0 >= WeeklyReview.attentionThreshold }.count
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Ring(value: score, size: 64, lineWidth: 7)
                    Spacer(minLength: 0)
                    Image(systemName: "figure.run").foregroundStyle(Palette.lime)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Consistency").font(.footnote).foregroundStyle(Palette.text)
                    Text(components.isEmpty ? "Log to start" : "\(onTrack) of \(components.count) on track")
                        .font(.caption2).foregroundStyle(Palette.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Consistency, \(Format.percent(score)), \(components.isEmpty ? "log to start" : "\(onTrack) of \(components.count) habits on track")")
        .accessibilityHint("Opens consistency details")
    }
}

/// Watch link status, like the design's battery pill. Turns amber when the watch stops writing to Apple Health.
private struct SyncStatus: View {
    let snapshot: HealthSnapshot
    let access: HealthAccess

    var body: some View {
        let latest = [snapshot.nights(calendar: .current).keys.max(), snapshot.hrv.keys.max()].compactMap { $0 }.max()
        let stale = access == .requested && DataFreshness.isStale(latestWatchDay: latest, now: .now, calendar: .current)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "applewatch")
                Text(pillText(latest: latest, stale: stale))
            }
            .font(.caption)
            .foregroundStyle(stale ? Palette.warn : Palette.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Palette.card, in: .capsule)
            .overlay(Capsule().strokeBorder(Palette.stroke))
            if stale, let latest {
                Text(DataFreshness.message(latestWatchDay: latest, calendar: .current))
                    .font(.footnote)
                    .foregroundStyle(Palette.text)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.warn.opacity(0.14), in: .rect(cornerRadius: 18))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func pillText(latest: String?, stale: Bool) -> String {
        guard access == .requested else { return access == .unavailable ? "Apple Health unavailable" : "Apple Health not connected" }
        guard let latest else { return "No watch data yet" }
        if latest == DayKey.of(.now, calendar: .current) { return "Watch synced today" }
        let day = DayKey.date(latest, calendar: .current)?.formatted(.dateTime.weekday(.abbreviated)) ?? latest
        return stale ? "No watch data since \(day)" : "Watch synced \(day)"
    }
}

/// One line in the Workouts card.
private struct WorkoutRow: View {
    struct Model: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let subtitle: String
        let minutes: Int?
        let time: Date
    }

    let model: Model

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.symbol)
                .font(.body)
                .foregroundStyle(Palette.lime)
                .frame(width: 44, height: 44)
                .background(Palette.track.opacity(0.5), in: .circle)
                .overlay(Circle().strokeBorder(Palette.stroke))
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title).font(.body).foregroundStyle(Palette.text).lineLimit(1)
                Text(model.subtitle).font(.caption).foregroundStyle(Palette.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let minutes = model.minutes { ValueText("\(minutes)", unit: "min", size: 24) }
        }
    }

    static func symbol(for activity: String) -> String {
        switch activity {
        case "Running": "figure.run"
        case "Walking", "Hiking": "figure.walk"
        case "Cycling": "figure.outdoor.cycle"
        case "Swimming": "figure.pool.swim"
        case "Yoga", "Pilates": "figure.yoga"
        case "Strength Training", "Core Training": "dumbbell.fill"
        case "HIIT": "flame.fill"
        default: "figure.mixed.cardio"
        }
    }
}
