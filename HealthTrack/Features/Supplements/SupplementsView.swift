import SwiftData
import SwiftUI

struct SupplementsView: View {
    @Query(sort: \Supplement.name) private var supplements: [Supplement]
    @State private var editing: Supplement?
    @State private var adding = false

    var body: some View {
        List {
            ForEach(supplements) { s in
                Button { editing = s } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(s.name).foregroundStyle(.primary).lineLimit(2)
                            if !s.active { Text("Paused").font(.caption).foregroundStyle(.orange) }
                        }
                        Text([s.dosageText, s.schedules.first.map(Self.describe) ?? "As needed"].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if supplements.isEmpty {
                ContentUnavailableView("No vitamins yet", systemImage: "pills",
                                       description: Text("Add the vitamins and supplements you take, on a schedule or as needed."))
            }
        }
        .navigationTitle("Vitamins & supplements")
        .toolbar { Button("Add", systemImage: "plus") { adding = true } }
        .sheet(item: $editing) { SupplementEditor(supplement: $0) }
        .sheet(isPresented: $adding) { SupplementEditor(supplement: nil) }
    }

    static func describe(_ schedule: SupplementSchedule) -> String {
        let days = schedule.daysOfWeek.isEmpty || schedule.daysOfWeek.count == 7
            ? "Every day"
            : schedule.daysOfWeek.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: " ")
        return [days, schedule.preferredTime?.rawValue.capitalized].compactMap { $0 }.joined(separator: ", ")
    }
}

/// One schedule per vitamin in the UI (take it twice a day? add it twice), or none: "as needed",
/// logged from the Vitamins page whenever you take it.
struct SupplementEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let supplement: Supplement?

    @State private var name = ""
    @State private var dosage = ""
    @State private var notes = ""
    @State private var active = true
    @State private var scheduled = true
    @State private var weekdays: Set<Int> = []
    @State private var dayPart: DayPart = .morning
    @State private var reminder = false
    @State private var reminderTime = TimeOfDay(8)
    @State private var startDate = Date()
    @State private var hasEnd = false
    @State private var endDate = Date()
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Vitamin D or Magnesium", text: $name)
                    TextField("Dose, e.g. 1000 IU", text: $dosage)
                    TextField("Notes", text: $notes, axis: .vertical)
                    Toggle("Active", isOn: $active)
                } footer: {
                    if !active { Text("Paused vitamins keep their history but aren't scheduled.") }
                }

                Section {
                    Toggle("Take on a schedule", isOn: $scheduled)
                } footer: {
                    if !scheduled { Text("As needed: log it from the Vitamins page whenever you take it. It won't count as missed.") }
                }

                if scheduled {
                Section("Schedule") {
                    HStack(spacing: 4) {
                        ForEach(1...7, id: \.self) { d in
                            let on = weekdays.isEmpty || weekdays.contains(d)
                            Button(Calendar.current.veryShortWeekdaySymbols[d - 1]) { toggle(d) }
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(on ? Color.accentColor : Color(.tertiarySystemFill), in: .circle)
                                .foregroundStyle(on ? Color.white : Color.primary)
                                .buttonStyle(.plain)
                                .accessibilityLabel(Calendar.current.weekdaySymbols[d - 1])
                                .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    Picker("Time of day", selection: $dayPart) {
                        ForEach(DayPart.allCases, id: \.self) { Text($0.rawValue.capitalized) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    Toggle("Ends", isOn: $hasEnd)
                    if hasEnd { DatePicker("Ends on", selection: $endDate, in: startDate..., displayedComponents: .date) }
                }

                Section {
                    Toggle("Reminder", isOn: $reminder)
                    if reminder {
                        DatePicker("At", selection: $reminderTime.asDate, displayedComponents: .hourAndMinute)
                    }
                }
                }

                if supplement != nil {
                    Section {
                        Button("Delete vitamin and its history", role: .destructive) { confirmDelete = true }
                    } footer: {
                        Text("To stop taking it but keep your history, turn off Active instead.")
                    }
                }
            }
            .navigationTitle(supplement == nil ? "Add vitamin" : "Edit vitamin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).bold().disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete \(name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let supplement { context.delete(supplement) }
                    dismiss()
                }
            } message: {
                Text("This also deletes every taken/missed record for it. This can't be undone.")
            }
            .onAppear(perform: load)
            .onChange(of: dayPart) { _, part in if !reminder { reminderTime = part.defaultTime } }
        }
    }

    /// Empty set = every day. Tapping a day when "every day" is on selects all but that day.
    private func toggle(_ d: Int) {
        if weekdays.isEmpty { weekdays = Set(1...7) }
        if weekdays.contains(d) { weekdays.remove(d) } else { weekdays.insert(d) }
        if weekdays.count == 7 { weekdays = [] }
    }

    private func load() {
        guard let s = supplement else { return }
        name = s.name
        dosage = s.dosageText
        notes = s.notes
        active = s.active
        scheduled = !s.schedules.isEmpty
        if let sch = s.schedules.first {
            weekdays = Set(sch.daysOfWeek)
            dayPart = sch.preferredTime ?? .morning
            reminder = sch.reminderEnabled
            reminderTime = sch.reminderTime ?? dayPart.defaultTime
            startDate = sch.startDate
            hasEnd = sch.endDate != nil
            endDate = sch.endDate ?? .now
        }
    }

    private func save() {
        let s = supplement ?? {
            let new = Supplement(name: name)
            context.insert(new)
            return new
        }()
        s.name = name.trimmingCharacters(in: .whitespaces)
        s.dosageText = dosage
        s.notes = notes
        s.updatedAt = .now
        guard scheduled else {
            context.makeAsNeeded(s)
            context.setActive(active, for: s)
            dismiss()
            return
        }
        let sch = s.schedules.first ?? {
            let new = SupplementSchedule(startDate: startDate)
            context.insert(new)
            new.supplement = s
            return new
        }()
        sch.daysOfWeek = weekdays.sorted()
        sch.preferredTimeRaw = dayPart.rawValue
        sch.reminderEnabled = reminder
        sch.reminderMinutes = reminder ? reminderTime.minutes : nil
        sch.startDate = startDate
        sch.endDate = hasEnd ? endDate : nil
        context.setActive(active, for: s)
        context.syncSupplementLogs(days: 0)   // today's dose appears immediately
        dismiss()
    }
}

/// The vitamin journal: tap what you took. Logged as taken now (or on the day being viewed).
struct VitaminLogSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Supplement.name) private var supplements: [Supplement]
    let day: Date

    @State private var name = ""
    @State private var dose = ""
    @State private var loggedIDs: [UUID] = []
    @State private var tapCount = 0

    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        NavigationStack {
            Form {
                if !supplements.isEmpty {
                    Section {
                        ForEach(supplements.filter(\.active)) { s in
                            let done = loggedIDs.contains(s.id)
                            Button { log(s) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.name).foregroundStyle(.primary)
                                        if !s.dosageText.isEmpty { Text(s.dosageText).font(.caption).foregroundStyle(.secondary) }
                                    }
                                    Spacer()
                                    Image(systemName: done ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(done ? Palette.good : Color.accentColor)
                                }
                            }
                            .accessibilityLabel(done ? "\(s.name), logged" : "Log \(s.name)")
                        }
                    } header: {
                        Text("Tap what you took")
                    } footer: {
                        Text("Logged as taken \(isToday ? "now" : "on \(day.formatted(.dateTime.weekday(.wide)))"). Extra doses don't change your adherence.")
                    }
                }
                Section {
                    TextField("Name, e.g. Vitamin C", text: $name)
                    TextField("Dose (optional)", text: $dose)
                    Button("Log it", systemImage: "plus", action: logNew)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Something else")
                } footer: {
                    Text("Saved as an as-needed vitamin, so next time it's one tap.")
                }
            }
            .navigationTitle("Log a vitamin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sensoryFeedback(.success, trigger: tapCount)
        }
    }

    private func log(_ s: Supplement) {
        if context.logVitamin(s, at: Calendar.current.timestamp(on: day)) != nil {
            loggedIDs.append(s.id)
            tapCount += 1
        }
    }

    private func logNew() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let existing = supplements.first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
        let s = existing ?? {
            let new = Supplement(name: trimmed, dosageText: dose.trimmingCharacters(in: .whitespaces))
            context.insert(new)
            return new
        }()
        log(s)
        name = ""
        dose = ""
    }
}
