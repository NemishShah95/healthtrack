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
                    if s.sortedExercises.isEmpty { Text("No exercises noted.").foregroundStyle(.secondary) }
                    ForEach(s.sortedExercises) { e in
                        LabeledContent(e.name, value: e.parsed.summary)
                    }
                    let volume = s.sortedExercises.compactMap(\.parsed.volumeKg).reduce(0, +)
                    if volume > 0 { LabeledContent("Volume", value: "\(Int(volume).formatted()) kg") }
                    if !s.notes.isEmpty { Text(s.notes).font(.callout).foregroundStyle(.secondary) }
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
        .navigationTitle(Calendar.current.isDateInToday(day) ? "Gym" : "Gym · \(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
        .sheet(item: $editing) { GymEditor(target: $0) }
    }
}

/// Add or edit a session: tap the areas trained, type exercises one per line.
struct GymEditor: View {
    enum Target: Identifiable {
        case new(day: Date)
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
    @State private var text = ""
    @State private var notes = ""
    @State private var time = Date()
    @State private var recent: [String] = []
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Focus") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(BodyPart.allCases, id: \.self) { part in
                            let on = focus.contains(part)
                            Button(part.title) {
                                if on { focus.remove(part) } else { focus.insert(part) }
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(on ? Color.red : Color(.tertiarySystemFill), in: .capsule)
                            .foregroundStyle(on ? Color.white : Color.primary)
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    TextField("Bench press 3x10 60 kg", text: $text, axis: .vertical)
                        .lineLimit(4...14)
                        .autocorrectionDisabled()
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(suggestions, id: \.self) { line in
                                    Button(line) { add(line) }
                                }
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    Text("One per line. Strength: sets x reps and weight, e.g. “Squat 5x5 100 kg”. Cardio: time and distance, e.g. “Treadmill 20 min 3 km”. Tap a recent one to repeat it.")
                }

                Section {
                    DatePicker("Time", selection: $time)
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                if case .edit = target {
                    Section {
                        Button("Delete session", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? "Log gym session" : "Edit session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).bold().disabled(focus.isEmpty && GymLog.parse(text).isEmpty)
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

    private var suggestions: [String] {
        let typed = Set(GymLog.parse(text).map { $0.name.lowercased() })
        return recent.filter { !typed.contains(GymLog.parseLine($0)?.name.lowercased() ?? "") }
    }

    private func add(_ line: String) {
        text = text.isEmpty || text.hasSuffix("\n") ? text + line : text + "\n" + line
    }

    /// Body-part order follows the chip order, not the order tapped.
    private var orderedFocus: [BodyPart] { BodyPart.allCases.filter(focus.contains) }

    private func load() {
        recent = context.recentExerciseLines()
        switch target {
        case .new(let day):
            time = Calendar.current.timestamp(on: day)
        case .edit(let s):
            focus = Set(s.focus)
            text = s.sortedExercises.map(\.parsed.line).joined(separator: "\n")
            notes = s.notes
            time = s.timestamp
        }
    }

    private func save() {
        let exercises = GymLog.parse(text)
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

struct GymHistoryView: View {
    @Query(sort: \GymSession.timestamp, order: .reverse) private var sessions: [GymSession]
    @State private var editing: GymEditor.Target?

    var body: some View {
        List {
            ForEach(sessions) { s in
                Button { editing = .edit(s) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).foregroundStyle(.primary)
                        Text("\(s.timestamp.formatted(date: .abbreviated, time: .shortened)) · \(s.exercises.count) exercise\(s.exercises.count == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
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
                Text(Self.summary(counts)).font(.subheadline).foregroundStyle(.secondary)
                Chart(BodyPart.allCases, id: \.self) { part in
                    BarMark(x: .value("Sessions", counts[part] ?? 0), y: .value("Body part", part.title))
                        .foregroundStyle(.red)
                        .annotation(position: .trailing) { Text("\(counts[part] ?? 0)").font(.caption) }
                }
                .frame(height: 320)
                Text("Gym sessions that trained each area in the last \(days) days.").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .padding()
        }
        .background(Color(.systemGroupedBackground))
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
