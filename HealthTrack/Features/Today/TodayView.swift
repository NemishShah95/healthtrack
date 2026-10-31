import SwiftData
import SwiftUI

/// Today plus the previous five days. Swipe or tap a date to see, fix or back-fill that day.
struct TodayView: View {
    static let daysBack = 5

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
                DayStrip(days: days, selection: $selection)
                TabView(selection: $selection) {
                    ForEach(Array(days.enumerated()), id: \.element) { i, day in
                        DayDashboard(day: day, isToday: i == Self.daysBack) { path.append($0) }
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
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

/// Detail pages reachable from the tiles.
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

private struct DayStrip: View {
    let days: [Date]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.element) { i, day in
                let selected = i == selection
                Button {
                    withAnimation { selection = i }
                } label: {
                    VStack(spacing: 2) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(selected ? Color(.systemBackground) : .secondary)
                        Text(day.formatted(.dateTime.day()))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(selected ? Color(.systemBackground) : .primary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(selected ? Color.accentColor : .clear, in: .rect(cornerRadius: 14))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(TodayView.title(for: day)), \(day.formatted(date: .complete, time: .omitted))")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
}

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
        let checkIn = checkIns.first
        let statuses = doses.map(\.status)   // reading these re-renders on every tick
        let record = context.dayRecords(from: day, through: day, health: health.snapshot, goals: goals).first
        let components = record.map { BehaviorScore.components($0.facts, goals: goals) } ?? [:]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2)

        ScrollView {
            VStack(spacing: 12) {
                if isToday, let settings = settingsRows.first {
                    RefreshBanner(status: ReinstallTracker.status(settings))
                }
                consistency(components)
                LazyVGrid(columns: columns, spacing: 12) {
                    sleepTile(goals: goals)
                    waterTile(goals: goals)
                    mealsTile(timings: record?.facts.mealTimings ?? [:], goals: goals)
                    proteinTile(goals: goals)
                    gymTile()
                    if !supplements.isEmpty { supplementsTile(statuses) }
                    activityTile(goals: goals)
                    checkInTile(checkIn)
                }
            }
            .padding()
        }
        .refreshable { await health.refresh() }
        .sheet(item: $editing) { MealEditor(target: $0) }
        .sheet(item: $editingGym) { GymEditor(target: $0) }
    }

    private func proteinTile(goals: Goals) -> some View {
        let total = protein.reduce(0) { $0 + $1.grams }
        return Tile(title: "Protein", systemImage: "p.circle.fill", tint: .pink, open: { open(.protein(day)) }) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(total) / \(goals.proteinTargetGrams) g").contentTransition(.numericText())
                ProgressView(value: min(1, Double(total) / Double(max(goals.proteinTargetGrams, 1)))).tint(.pink)
            }
        } accessory: {
            PillButton(title: "+20 g", tint: .pink, accessibilityLabel: "Add 20 grams of protein") {
                context.logProtein(20, at: Calendar.current.timestamp(on: day))
            }
        }
    }

    private func gymTile() -> some View {
        let exercises = gym.reduce(0) { $0 + $1.exercises.count }
        return Tile(title: "Gym", systemImage: "dumbbell.fill", tint: .red,
                    detail: gym.isEmpty ? nil : (gym.count > 1 ? "\(gym.count) sessions" : "\(exercises) exercise\(exercises == 1 ? "" : "s")"),
                    open: { open(.gym(day)) }) {
            if let last = gym.last {
                Text(last.focus.isEmpty ? "Workout" : last.focus.map(\.title).joined(separator: ", "))
            } else {
                Placeholder("Not logged")
            }
        } accessory: {
            if gym.isEmpty {
                PillButton(title: "+ Log", tint: .red, accessibilityLabel: "Log a gym session") { editingGym = .new(day: day) }
            }
        }
    }

    private func consistency(_ components: [ScoreComponent: Double]) -> some View {
        let score = BehaviorScore.score(components)
        let onTrack = components.values.filter { $0 >= WeeklyReview.attentionThreshold }.count
        return Button { open(.consistency(day)) } label: {
            HStack(spacing: 16) {
                Ring(value: score)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily consistency").font(.headline)
                    Text(components.isEmpty ? "Log something to get started" : "\(onTrack) of \(components.count) habits on track")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func sleepTile(goals: Goals) -> some View {
        let night = health.snapshot.nights(calendar: .current)[key]
        var notes: [String] = []
        if let n = night {
            let bed = goals.bedtime.signedMinutes(to: TimeOfDay(of: n.sleepStart, in: .current))
            let wake = goals.wakeTime.signedMinutes(to: TimeOfDay(of: n.finalWake, in: .current))
            if bed > goals.sleepToleranceMinutes { notes.append("Late to bed") }
            if bed < -goals.sleepToleranceMinutes { notes.append("Early to bed") }
            if abs(wake) > goals.sleepToleranceMinutes { notes.append(wake > 0 ? "Woke late" : "Woke early") }
            if n.asleep / 60 < Double(goals.sleepTargetMinutes) { notes.append("Short") }
        }
        return Tile(title: "Sleep", systemImage: "bed.double.fill", tint: .indigo,
                    detail: night == nil ? nil : (notes.isEmpty ? "On target" : notes.prefix(2).joined(separator: " · ")),
                    open: { open(.sleep(day)) }) {
            if let night { Text(Format.duration(night.asleep)) } else { Placeholder("No data") }
        } accessory: { EmptyView() }
    }

    private func waterTile(goals: Goals) -> some View {
        let total = water.reduce(0) { $0 + $1.amountML }
        return Tile(title: "Water", systemImage: "drop.fill", tint: .blue, open: { open(.water(day)) }) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Hydration.progressText(totalML: total, targetML: goals.waterTargetML))
                    .contentTransition(.numericText())
                ProgressView(value: min(1, Double(total) / Double(max(goals.waterTargetML, 1)))).tint(.blue)
            }
        } accessory: {
            PillButton(title: "+250", tint: .blue, accessibilityLabel: "Add 250 millilitres") {
                context.logWater(250, at: Calendar.current.timestamp(on: day))
            }
        }
    }

    private func mealsTile(timings: [MealType: MealTiming], goals: Goals) -> some View {
        let logged = Set(meals.map(\.mealType))
        let next = MealRoutine.nextMeal(logged: logged, windows: goals.mealWindows,
                                        now: isToday ? TimeOfDay(of: .now, in: .current) : TimeOfDay(23, 59))
        return Tile(title: "Meals", systemImage: "fork.knife", tint: Palette.meals,
                    detail: next == nil ? "All logged" : nil, open: { open(.meals(day)) }) {
            HStack(spacing: 10) {
                ForEach(MealType.targeted, id: \.self) { type in
                    let timing = timings[type] ?? .pending
                    VStack(spacing: 2) {
                        Image(systemName: timing.symbol).foregroundStyle(timing.color)
                        Text(type.rawValue.prefix(1).uppercased()).font(.caption2).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(type.rawValue) \(timing.label)")
                }
            }
        } accessory: {
            if let next {
                PillButton(title: "+ \(next.rawValue.capitalized)", tint: .orange, accessibilityLabel: "Log \(next.rawValue)") {
                    if isToday {
                        context.logMeal(next)
                    } else {
                        editing = .new(day: day, type: next)   // past day: pick the time
                    }
                }
            }
        }
    }

    private func supplementsTile(_ statuses: [SupplementStatus]) -> some View {
        let taken = statuses.filter { $0 == .taken }.count
        let open = statuses.contains { $0 == .pending || $0 == .missed }
        return Tile(title: "Supplements", systemImage: "pills.fill", tint: .purple,
                    detail: statuses.isEmpty ? nil : "taken", open: { self.open(.supplements(day)) }) {
            if statuses.isEmpty { Placeholder("None today") } else { Text("\(taken)/\(statuses.count)") }
        } accessory: {
            if open {
                PillButton(title: "All ✓", tint: .purple, accessibilityLabel: "Mark all supplements taken") {
                    context.markAllTaken(onDay: key)
                }
            }
        }
    }

    private func activityTile(goals: Goals) -> some View {
        let s = health.snapshot
        let workouts = context.workoutsThisWeek(containing: day, health: s, goals: goals)
        return Tile(title: "Steps", systemImage: "figure.walk", tint: Palette.steps,
                    detail: "\(workouts)/\(goals.workoutsPerWeek) workouts this week", open: { open(.activity(day)) }) {
            if let steps = s.steps[key] { Text(steps.formatted()) } else { Placeholder("No data") }
        } accessory: { EmptyView() }
    }

    private func checkInTile(_ c: DailyCheckIn?) -> some View {
        let done = c?.energy != nil || c?.mood != nil || c?.stress != nil
        return Tile(title: "Check-in", systemImage: "face.smiling", tint: Palette.checkIn,
                    detail: done ? "Energy · Mood · Stress" : "Three taps", open: { open(.checkIn(day)) }) {
            if done {
                Text([c?.energy, c?.mood, c?.stress].map { $0.map(String.init) ?? "–" }.joined(separator: " · "))
            } else {
                Text("How are you?")
            }
        } accessory: { EmptyView() }
    }
}
