import SwiftData
import SwiftUI

/// Training goals ("Run 5 km, 3× a week", "Push-ups 3×15") and how they're going, from the gym journal.
struct TrainingView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]
    @Query(sort: \GymSession.timestamp, order: .reverse) private var sessions: [GymSession]
    @State private var editingGoal: TrainingGoalEditor.Target?
    @State private var logging: GymEditor.Target?

    var body: some View {
        let goals = settingsRows.first?.goals.trainingGoals ?? []
        let _ = sessions.map(\.updatedAt)   // re-read the journal whenever a session changes
        let log = context.trainingLog()
        let progress = goals.map { (goal: $0, progress: GoalProgress.of($0, sessions: log, calendar: .current)) }
        let weekly = progress.filter { !$0.goal.isMilestone }
        let milestones = progress.filter(\.goal.isMilestone)

        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    summary(weekly: weekly, milestones: milestones)
                    if goals.isEmpty {
                        emptyState
                    }
                    if !weekly.isEmpty {
                        SectionLabel("Weekly goals").padding(.top, 8)
                        ForEach(weekly, id: \.goal.id) { goalCard($0.goal, $0.progress) }
                    }
                    if !milestones.isEmpty {
                        SectionLabel("Milestones").padding(.top, 8)
                        ForEach(milestones, id: \.goal.id) { goalCard($0.goal, $0.progress) }
                    }
                    recentSessions
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("Training")
            .toolbar {
                Button("Add goal", systemImage: "plus") { editingGoal = .new }
            }
            .sheet(item: $editingGoal) { TrainingGoalEditor(target: $0) }
            .sheet(item: $logging) { GymEditor(target: $0) }
        }
    }

    // MARK: Pieces

    private func summary(weekly: [(goal: TrainingGoal, progress: GoalProgress)],
                         milestones: [(goal: TrainingGoal, progress: GoalProgress)]) -> some View {
        let week = WeeklyReview.week(containing: .now, calendar: .current)
        let thisWeek = sessions.filter { week.contains($0.timestamp) && $0.timestamp < week.end }.count
        let onTrack = weekly.filter { $0.progress.doneThisWeek >= $0.goal.timesPerWeek }.count
        let overall = weekly.isEmpty ? nil : weekly.map { $0.progress.fraction(for: $0.goal) }.mean
        return HStack(spacing: 16) {
            Ring(value: overall, size: 92, lineWidth: 9)
            VStack(alignment: .leading, spacing: 6) {
                Text("This week").font(.subheadline).foregroundStyle(Palette.secondary)
                ValueText("\(onTrack)/\(weekly.count)", unit: "goals done", size: 30)
                Text("\(thisWeek) session\(thisWeek == 1 ? "" : "s") logged · \(milestones.filter { $0.progress.achievedOn != nil }.count)/\(milestones.count) milestones")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .card()
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "target").font(.title).foregroundStyle(Palette.lime)
            Text("Set a training goal").font(.title3.weight(.regular)).foregroundStyle(Palette.text)
            Text("For example: run 5 km three times a week, 3 sets of 15 push-ups, or a first 10 km run. Goals tick off from what you log in the gym journal.")
                .font(.subheadline).foregroundStyle(Palette.secondary)
            PillButton(title: "+ Add a goal", accessibilityLabel: "Add a training goal") { editingGoal = .new }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func goalCard(_ goal: TrainingGoal, _ p: GoalProgress) -> some View {
        let ringLabel = goal.isMilestone ? (p.achievedOn != nil ? "✓" : Format.percent(p.best)) : "\(p.doneThisWeek)/\(goal.timesPerWeek)"
        return ZStack(alignment: .bottomTrailing) {
            Button { editingGoal = .edit(goal) } label: {
                HStack(alignment: .top, spacing: 14) {
                    Ring(value: p.fraction(for: goal), size: 64, lineWidth: 7, label: ringLabel)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goal.title).font(.body).foregroundStyle(Palette.text).fixedSize(horizontal: false, vertical: true)
                        Text(status(goal, p)).font(.caption).foregroundStyle(Palette.secondary)
                        if !goal.isMilestone { WeekHistory(weeks: p.recentWeeks) }
                    }
                    Spacer(minLength: 56)
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                .card()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(goal.title), \(status(goal, p))")
            .accessibilityHint("Edit this goal")
            PillButton(title: "+ Log", accessibilityLabel: "Log \(goal.exercise)") {
                logging = .new(day: Calendar.current.startOfDay(for: .now), preset: goal.target)
            }
            .padding(8)
        }
    }

    private func status(_ goal: TrainingGoal, _ p: GoalProgress) -> String {
        if goal.isMilestone {
            if let day = p.achievedOn { return "Achieved \(day.formatted(.dateTime.day().month(.abbreviated).year()))" }
            return p.best > 0 ? "Best so far: \(Format.percent(p.best)) of the target" : "Not done yet"
        }
        let streak = p.streak > 0 ? " · \(p.streak)-week streak" : ""
        return "\(goal.cadenceText) · \(p.doneThisWeek) done this week\(streak)"
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent sessions").font(.headline.weight(.regular)).foregroundStyle(Palette.text)
                Spacer()
                PillButton(title: "+ Log", accessibilityLabel: "Log a gym session") {
                    logging = .new(day: Calendar.current.startOfDay(for: .now))
                }
            }
            if sessions.isEmpty {
                Text("Nothing logged yet").font(.subheadline).foregroundStyle(Palette.secondary)
            }
            ForEach(sessions.prefix(4)) { s in
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill").foregroundStyle(Palette.lime)
                        .frame(width: 44, height: 44)
                        .background(Palette.track.opacity(0.5), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).foregroundStyle(Palette.text).lineLimit(1)
                        Text("\(s.timestamp.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(s.sortedExercises.map(\.name).joined(separator: ", "))")
                            .font(.caption).foregroundStyle(Palette.secondary).lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            NavigationLink { GymHistoryView() } label: {
                Text("Gym history").font(.subheadline).foregroundStyle(Palette.lime)
            }
            NavigationLink {
                BodyPartFocusView(counts: TrendSeries.bodyPartCounts(days: 30, context: context), days: 30)
            } label: {
                Text("Body part focus").font(.subheadline).foregroundStyle(Palette.lime)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .padding(.top, 8)
    }
}

/// The last weeks as small bars, oldest first: lime when the weekly goal was reached.
private struct WeekHistory: View {
    let weeks: [Bool]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { i, met in
                Capsule()
                    .fill(met ? Palette.lime : Palette.track)
                    .frame(width: 14, height: 4)
                    .overlay(alignment: .bottom) {
                        if i == weeks.count - 1 { Capsule().fill(Palette.text.opacity(0.5)).frame(width: 4, height: 2).offset(y: 5) }
                    }
            }
        }
        .padding(.bottom, 4)
        .accessibilityElement()
        .accessibilityLabel("Reached in \(weeks.filter { $0 }.count) of the last \(weeks.count) weeks")
    }
}

/// Add or edit a training goal. Every input is a dropdown.
struct TrainingGoalEditor: View {
    enum Target: Identifiable {
        case new
        case edit(TrainingGoal)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let g): g.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let target: Target

    @State private var goalTarget = ParsedExercise(name: "")
    @State private var timesPerWeek = 3
    @State private var recent: [String] = []
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        NameMenu(title: "Exercise name", groups: groups, pick: choose) {
                            DropdownLabel(title: "Exercise", value: goalTarget.name.isEmpty ? "Choose" : goalTarget.name)
                        }
                        .accessibilityLabel("Exercise")
                        .accessibilityValue(goalTarget.name.isEmpty ? "Choose" : goalTarget.name)
                    }
                    if !goalTarget.name.isEmpty {
                        Section {
                            ForEach(ExerciseCatalog.kind(of: goalTarget.name, sample: goalTarget).fields, id: \.self) { field in
                                Picker(field.title, selection: $goalTarget[dynamicMember: field.keyPath]) {
                                    Text("Any").tag(Double?.none)
                                    ForEach(field.options(including: goalTarget[keyPath: field.keyPath]), id: \.self) {
                                        Text(field.format($0)).tag(Double?.some($0))
                                    }
                                }
                            }
                        } header: {
                            Text("Target")
                        } footer: {
                            Text("A logged \(goalTarget.name.lowercased()) counts when it reaches every number you set here.")
                        }
                    }
                    Section {
                        Picker("How often", selection: $timesPerWeek) {
                            Text("Once (milestone)").tag(0)
                            ForEach(1...7, id: \.self) { Text("\($0)× a week").tag($0) }
                        }
                    } footer: {
                        Text(timesPerWeek == 0 ? "A milestone is achieved the first time you log it." : "Counts the days each week you reach the target.")
                    }
                    if case .edit = target {
                        Section {
                            Button("Delete goal", role: .destructive) { confirmDelete = true }
                        } footer: {
                            Text("Your gym journal isn't affected.")
                        }
                    }
                }
                .appRows()
            }
            .appScreen()
            .navigationTitle(isNew ? "New training goal" : "Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).bold().disabled(goalTarget.name.isEmpty)
                }
            }
            .confirmationDialog("Delete this goal?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if case .edit(let g) = target { context.deleteTrainingGoal(id: g.id) }
                    dismiss()
                }
            }
            .onAppear(perform: load)
        }
    }

    private var isNew: Bool { if case .new = target { true } else { false } }

    private var groups: [(title: String, names: [String])] {
        let all = ExerciseCatalog.all
        return [("Recent", recent),
                ("Cardio", all.filter { $0.kind == .cardio }.map(\.name)),
                ("Bodyweight & core", all.filter { $0.kind == .bodyweight || $0.kind == .timed }.map(\.name)),
                ("Weights", all.filter { $0.kind == .strength }.map(\.name))]
    }

    /// Sensible starting target: 5 km for cardio, otherwise the usual starting numbers.
    private func choose(_ name: String) {
        goalTarget = ExerciseCatalog.kind(of: name) == .cardio ? ParsedExercise(name: name, distanceKm: 5) : ExerciseCatalog.starter(name)
    }

    private func load() {
        recent = context.recentExercises().map(\.name)
        if case .edit(let g) = target {
            goalTarget = g.target
            timesPerWeek = g.timesPerWeek
        }
    }

    private func save() {
        // Keep only the fields that make sense for this exercise.
        var clean = ParsedExercise(name: goalTarget.name)
        for field in ExerciseCatalog.kind(of: goalTarget.name, sample: goalTarget).fields {
            clean[keyPath: field.keyPath] = goalTarget[keyPath: field.keyPath]
        }
        switch target {
        case .new:
            context.saveTrainingGoal(TrainingGoal(target: clean, timesPerWeek: timesPerWeek))
        case .edit(var g):
            g.target = clean
            g.timesPerWeek = timesPerWeek
            context.saveTrainingGoal(g)
        }
        dismiss()
    }
}
