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
                        Text([s.dosageText, s.schedules.first.map(Self.describe)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if supplements.isEmpty {
                ContentUnavailableView("No supplements", systemImage: "pills",
                                       description: Text("Add the vitamins and supplements you take."))
            }
        }
        .navigationTitle("Supplements")
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

/// One schedule per supplement in the UI. Take something twice a day? Add it twice ("Vitamin C — evening").
struct SupplementEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let supplement: Supplement?

    @State private var name = ""
    @State private var dosage = ""
    @State private var notes = ""
    @State private var active = true
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
                    TextField("Name, e.g. Vitamin D", text: $name)
                    TextField("Dose, e.g. 1000 IU", text: $dosage)
                    TextField("Notes", text: $notes, axis: .vertical)
                    Toggle("Active", isOn: $active)
                } footer: {
                    if !active { Text("Paused supplements keep their history but aren't scheduled.") }
                }

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

                if supplement != nil {
                    Section {
                        Button("Delete supplement and its history", role: .destructive) { confirmDelete = true }
                    } footer: {
                        Text("To stop taking it but keep your history, turn off Active instead.")
                    }
                }
            }
            .navigationTitle(supplement == nil ? "Add supplement" : "Edit supplement")
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
