import Charts
import SwiftData
import SwiftUI

/// One day's gym journal, next to whatever the watch recorded.
struct GymDetail: View {
    @Environment(\.modelContext) private var context
    @Environment(HealthStore.self) private var health
    @Query private var sessions: [GymSession]
    @State private var editing: GymEditor.Target?
    let day: Date
    let key: String

    init(day: Date) {
        let key = DayKey.of(day, calendar: .current)
        self.day = day
        self.key = key
        _sessions = Query(filter: #Predicate<GymSession> { $0.day == key }, sort: \.timestamp)
    }

    var body: some View {
        let last = context.lastGymSession(before: key)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        let watch = health.snapshot.workouts.filter { $0.start >= day && $0.start < end }
        List {
            Group {
                Section {
                    Button("Log a session…", systemImage: "square.and.pencil") { editing = .new(day: day) }
                    if let last {
                        Button {
                            context.duplicate(last, at: Calendar.current.timestamp(on: day))
                        } label: {
                            Label("Repeat \(last.title) from \(last.timestamp.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))",
                                  systemImage: "arrow.clockwise")
                        }
                    }
                }
                ForEach(sessions) { s in
                    Section {
                        if s.sortedExercises.isEmpty { Text("No exercises noted.").foregroundStyle(Palette.secondary) }
                        ForEach(s.sortedExercises) { e in
                            LabeledContent(e.name, value: e.parsed.summary)
                        }
                        let volume = s.sortedExercises.compactMap(\.parsed.volumeKg).reduce(0, +)
                        if volume > 0 { LabeledContent("Volume", value: "\(Int(volume).formatted()) kg") }
                        if !s.notes.isEmpty { Text(s.notes).font(.callout).foregroundStyle(Palette.secondary) }
                        Button("Edit") { editing = .edit(s) }
                    } header: {
                        Text("\(s.title) · \(s.timestamp.formatted(date: .omitted, time: .shortened))")
                    }
                }
                if !watch.isEmpty {
                    Section {
                        ForEach(Array(watch.enumerated()), id: \.offset) { _, w in
                            LabeledContent(w.activityName, value: Format.duration(w.duration))
                        }
                    } header: {
                        Text("From your watch")
                    } footer: {
                        Text("A journaled session and a watch workout on the same day count as one workout.")
                    }
                }
                Section {
                    NavigationLink("Gym history") { GymHistoryView() }
                }
            }
            .appRows()
        }
        .appScreen()
        .navigationTitle(Calendar.current.isDateInToday(day) ? "Gym" : "Gym · \(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
        .sheet(item: $editing) { GymEditor(target: $0) }
    }
}

/// Add or edit a session: body parts and exercises from dropdowns, numbers from dropdowns. No typing.
struct GymEditor: View {
    enum Target: Identifiable {
        /// `preset`: start with this exercise (logging against a training goal).
        case new(day: Date, preset: ParsedExercise? = nil)
        case edit(GymSession)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let s): s.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let target: Target

    @State private var focus: Set<BodyPart> = []
    @State private var exercises: [ParsedExercise] = []
    @State private var notes = ""
    @State private var time = Date()
    @State private var recent: [ParsedExercise] = []
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        MultiSelectMenu(title: "Body parts", options: BodyPart.allCases, selection: $focus, label: \.title)
                    } header: {
                        Text("Focus")
                    }

                    Section {
                        ForEach(Array(exercises.indices), id: \.self) { i in
                            // Bounds-checked: a swipe-to-delete can redraw a row whose index is already gone.
                            ExerciseRow(exercise: Binding(
                                get: { exercises.indices.contains(i) ? exercises[i] : ParsedExercise(name: "") },
                                set: { if exercises.indices.contains(i) { exercises[i] = $0 } }))
                        }
                        .onDelete { exercises.remove(atOffsets: $0) }
                        NameMenu(title: "Exercise name", groups: menuGroups, pick: add) {
                            Label("Add exercise", systemImage: "plus.circle.fill").foregroundStyle(Palette.lime)
                        }
                        .accessibilityLabel("Add exercise")
                    } header: {
                        Text("Exercises")
                    } footer: {
                        Text("Pick an exercise, then set its numbers. Your recent ones come first, with last time's numbers. Swipe left to remove one.")
                    }

                    Section {
                        DatePicker("Time", selection: $time)
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                    }

                    if case .edit = target {
                        Section {
                            Button("Delete session", role: .destructive) { confirmDelete = true }
                        }
                    }
                }
                .appRows()
            }
            .appScreen()
            .navigationTitle(isNew ? "Log gym session" : "Edit session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).bold().disabled(focus.isEmpty && exercises.isEmpty)
                }
            }
            .confirmationDialog("Delete this session?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if case .edit(let s) = target { context.delete(s) }
                    dismiss()
                }
            }
            .onAppear(perform: load)
        }
    }

    private var isNew: Bool { if case .new = target { true } else { false } }

    /// Recent (with last time's numbers), then the catalogue for the chosen body parts, then everything else.
    private var menuGroups: [(title: String, names: [String])] {
        let ordered = ExerciseCatalog.names(for: orderedFocus)
        let matching = orderedFocus.isEmpty ? [] : ordered.filter { name in ExerciseCatalog.entry(named: name).map { orderedFocus.contains($0.part) } ?? false }
        let rest = ordered.filter { !matching.contains($0) }
        return [("Recent", recent.map(\.name)),
                (orderedFocus.isEmpty ? "Exercises" : orderedFocus.map(\.title).joined(separator: ", "), orderedFocus.isEmpty ? rest : matching),
                ("More", orderedFocus.isEmpty ? [] : rest)]
    }

    private func add(_ name: String) {
        exercises.append(recent.first { $0.name.caseInsensitiveCompare(name) == .orderedSame } ?? ExerciseCatalog.starter(name))
    }

    /// Body-part order follows the list order, not the order tapped.
    private var orderedFocus: [BodyPart] { BodyPart.allCases.filter(focus.contains) }

    private func load() {
        recent = context.recentExercises()
        switch target {
        case .new(let day, let preset):
            time = Calendar.current.timestamp(on: day)
            if let preset {
                exercises = [preset]
                if let part = ExerciseCatalog.entry(named: preset.name)?.part { focus = [part] }
            }
        case .edit(let s):
            focus = Set(s.focus)
            exercises = s.sortedExercises.map(\.parsed)
            notes = s.notes
            time = s.timestamp
        }
    }

    private func save() {
        switch target {
        case .new:
            context.logGym(focus: orderedFocus, exercises: exercises, at: time, notes: notes)
        case .edit(let s):
            s.focus = orderedFocus
            s.notes = notes
            if s.timestamp != time {
                s.timestamp = time
                s.day = DayKey.of(time, calendar: .current)
            }
            context.replaceExercises(of: s, with: exercises)
        }
        dismiss()
    }
}

/// An exercise name with a dropdown per number that makes sense for it.
struct ExerciseRow: View {
    @Binding var exercise: ParsedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.name).font(.body).foregroundStyle(Palette.text)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { menus }
                VStack(alignment: .leading, spacing: 8) { menus }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var menus: some View {
        ForEach(exercise.visibleFields, id: \.self) { field in
            NumberMenu(field: field, value: $exercise[dynamicMember: field.keyPath], accessibilityName: exercise.name)
        }
    }
}

struct GymHistoryView: View {
    @Query(sort: \GymSession.timestamp, order: .reverse) private var sessions: [GymSession]
    @State private var editing: GymEditor.Target?

    var body: some View {
        List {
            ForEach(sessions) { s in
                Button { editing = .edit(s) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).foregroundStyle(Palette.text)
                        Text("\(s.timestamp.formatted(date: .abbreviated, time: .shortened)) · \(s.exercises.count) exercise\(s.exercises.count == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
            }
            .appRows()
        }
        .appScreen()
        .overlay { if sessions.isEmpty { ContentUnavailableView("No sessions yet", systemImage: "dumbbell") } }
        .navigationTitle("Gym history")
        .sheet(item: $editing) { GymEditor(target: $0) }
    }
}

/// How often each area was trained over a period.
struct BodyPartFocusView: View {
    let counts: [BodyPart: Int]
    let days: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(Self.summary(counts)).font(.subheadline).foregroundStyle(Palette.secondary)
                Chart(BodyPart.allCases, id: \.self) { part in
                    BarMark(x: .value("Sessions", counts[part] ?? 0), y: .value("Body part", part.title))
                        .foregroundStyle(Palette.lime.gradient)
                        .cornerRadius(4)
                        .annotation(position: .trailing) { Text("\(counts[part] ?? 0)").font(.caption).foregroundStyle(Palette.text) }
                }
                .chartXAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Palette.track); AxisValueLabel().foregroundStyle(Palette.secondary) } }
                .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Palette.text) } }
                .frame(height: 320)
                Text("Gym sessions that trained each area in the last \(days) days.").font(.caption).foregroundStyle(Palette.secondary)
            }
            .padding()
            .card()
            .padding()
        }
        .appScreen()
        .navigationTitle("Body part focus")
        .navigationBarTitleDisplayMode(.inline)
    }

    static func summary(_ counts: [BodyPart: Int]) -> String {
        let areas = BodyPart.allCases.filter { $0 != .fullBody }
        // Ties resolve to the earlier area in the list, so the summary is stable.
        guard let most = areas.max(by: { (counts[$0] ?? 0) < (counts[$1] ?? 0) }),
              (counts[most] ?? 0) > 0,
              let least = areas.min(by: { (counts[$0] ?? 0) < (counts[$1] ?? 0) }) else { return "No gym sessions logged" }
        return "Most: \(most.title) · Least: \(least.title)"
    }
}
