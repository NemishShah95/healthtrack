import SwiftData
import SwiftUI

struct LogView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var day = Calendar.current.startOfDay(for: .now)

    var body: some View {
        NavigationStack {
            LogList(day: day)
                .id(day)
                .navigationTitle("Log")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { day = Calendar.current.startOfDay(for: .now) }
        }
    }
}

private struct LogList: View {
    @Environment(\.modelContext) private var context
    @Query private var meals: [Meal]
    @Query private var water: [WaterEntry]
    @Query private var doses: [SupplementLog]
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]
    @State private var editing: MealEditor.Target?
    let key: String

    init(day: Date) {
        let key = DayKey.of(day, calendar: .current)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        self.key = key
        _meals = Query(filter: #Predicate<Meal> { $0.day == key }, sort: \.timestamp)
        _water = Query(filter: #Predicate<WaterEntry> { $0.timestamp >= day && $0.timestamp < end }, sort: \.timestamp, order: .reverse)
        _doses = Query(filter: #Predicate<SupplementLog> { $0.day == key })
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach([MealType.breakfast, .lunch, .dinner, .snack], id: \.self) { type in
                            Button("\(type.rawValue.capitalized) ✓") { context.logMeal(type) }
                                .accessibilityLabel("Log \(type.rawValue) now")
                        }
                        ForEach(savedMeals) { saved in
                            Button(saved.name, systemImage: "star") { context.logSavedMeal(saved) }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Button("Add meal with foods…", systemImage: "square.and.pencil") { editing = .new }
                ForEach(meals) { meal in
                    MealRow(meal: meal)
                        .contentShape(.rect)
                        .onTapGesture { editing = .edit(meal) }
                        .contextMenu { MealActions(meal: meal) }
                }
                .onDelete { for i in $0 { context.delete(meals[i]) } }
                NavigationLink("Meal history") { MealHistoryView() }
            } header: {
                Text("Meals")
            } footer: {
                Text("One tap logs a meal now. Add foods and grams only when you want the detail.")
            }

            Section("Water") {
                WaterButtons()
                ForEach(water) { entry in
                    LabeledContent("\(entry.amountML) ml", value: entry.timestamp.formatted(date: .omitted, time: .shortened))
                }
                .onDelete { for i in $0 { context.delete(water[i]) } }
            }

            Section("Supplements") {
                let sorted = context.supplementLogs(from: key, through: key)
                if sorted.isEmpty {
                    Text("Nothing scheduled today.").foregroundStyle(.secondary)
                } else {
                    ForEach(sorted) { DoseRow(log: $0) }
                    if sorted.contains(where: { $0.status == .pending }) {
                        Button("Mark all taken", systemImage: "checkmark.circle") { context.markAllTaken(onDay: key) }
                    }
                }
                NavigationLink("Manage supplements") { SupplementsView() }
            }
            .onAppear { _ = doses.count }

            Section("Check-in") {
                CheckInControls(dayKey: key)
                CheckInNotes(dayKey: key)
            }
        }
        .sheet(item: $editing) { MealEditor(target: $0) }
    }
}

struct MealRow: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(meal.title).font(.headline)
                Spacer()
                Text(meal.localTime.formatted()).foregroundStyle(.secondary).monospacedDigit()
            }
            let foods = meal.sortedFoods.map { ParsedFood(name: $0.foodName, grams: $0.grams).line }
            if !foods.isEmpty {
                Text(foods.joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            }
            if !meal.notes.isEmpty { Text(meal.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Repeat now / save as usual / delete.
struct MealActions: View {
    @Environment(\.modelContext) private var context
    let meal: Meal

    var body: some View {
        Button("Repeat now", systemImage: "arrow.clockwise") { context.duplicate(meal) }
        Button("Save as usual \(meal.mealType.rawValue)", systemImage: "star") {
            context.saveAsUsual(meal, name: "Usual \(meal.mealType.rawValue)")
        }
        Button("Delete", systemImage: "trash", role: .destructive) { context.delete(meal) }
    }
}

private struct CheckInNotes: View {
    @Environment(\.modelContext) private var context
    @Query private var checkIns: [DailyCheckIn]
    @State private var text = ""
    let dayKey: String

    init(dayKey: String) {
        self.dayKey = dayKey
        _checkIns = Query(filter: #Predicate<DailyCheckIn> { $0.day == dayKey })
    }

    var body: some View {
        TextField("Notes (optional)", text: $text, axis: .vertical)
            .onAppear { text = checkIns.first?.notes ?? "" }
            .onSubmit(save)
            .onDisappear(perform: save)
    }

    private func save() {
        guard text != (checkIns.first?.notes ?? "") else { return }
        let c = context.checkIn(onDay: dayKey)
        c.notes = text
        c.updatedAt = .now
    }
}

struct MealHistoryView: View {
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]
    @State private var editing: MealEditor.Target?

    var body: some View {
        let byDay = Dictionary(grouping: meals, by: \.day)
        List {
            ForEach(byDay.keys.sorted(by: >), id: \.self) { day in
                Section(DayKey.date(day, calendar: .current)?.formatted(date: .complete, time: .omitted) ?? day) {
                    ForEach(byDay[day] ?? []) { meal in
                        MealRow(meal: meal)
                            .contentShape(.rect)
                            .onTapGesture { editing = .edit(meal) }
                            .contextMenu { MealActions(meal: meal) }
                    }
                }
            }
        }
        .overlay { if meals.isEmpty { ContentUnavailableView("No meals yet", systemImage: "fork.knife") } }
        .navigationTitle("Meal history")
        .sheet(item: $editing) { MealEditor(target: $0) }
    }
}
