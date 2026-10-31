import SwiftData
import SwiftUI

/// Add or edit a meal. Foods are optional: one per line, grams optional ("oats 80 g").
struct MealEditor: View {
    enum Target: Identifiable {
        /// New meal; `day` nil = now, `type` nil = guess from the clock.
        case new(day: Date?, type: MealType?)
        case edit(Meal)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let meal): meal.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsRows: [AppSettings]
    let target: Target

    @State private var type: MealType = .breakfast
    @State private var customName = ""
    @State private var time = Date()
    @State private var foodsText = ""
    @State private var notes = ""
    @State private var rating = 0
    @State private var recent: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Picker("Meal", selection: $type) {
                    ForEach(MealType.allCases, id: \.self) { Text($0.rawValue.capitalized) }
                }
                if type == .custom { TextField("Name", text: $customName) }
                DatePicker("Time", selection: $time)

                Section {
                    TextField("e.g. oats 80 g", text: $foodsText, axis: .vertical)
                        .lineLimit(3...12)
                        .textInputAutocapitalization(.never)
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(suggestions, id: \.self) { name in
                                    Button { add(name) } label: {
                                        Label(name, systemImage: favourites.contains(name) ? "star.fill" : "plus")
                                    }
                                    .contextMenu {
                                        Button(favourites.contains(name) ? "Remove from favourites" : "Add to favourites",
                                               systemImage: "star") { toggleFavourite(name) }
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                } header: {
                    Text("Foods (optional)")
                } footer: {
                    Text("One per line. Add grams if you like: “banana 120 g”. Long-press a suggestion to favourite it.")
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                    Picker("How did it feel?", selection: $rating) {
                        Text("—").tag(0)
                        ForEach(1...5, id: \.self) { Text("\($0) / 5").tag($0) }
                    }
                }

                if case .edit(let meal) = target {
                    Section {
                        Button("Delete meal", role: .destructive) {
                            context.delete(meal)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add meal" : "Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).bold() }
            }
            .onAppear(perform: load)
        }
    }

    private var isNew: Bool { if case .new = target { true } else { false } }
    private var favourites: [String] { settingsRows.first?.favoriteFoods ?? [] }
    private var suggestions: [String] {
        let typed = Set(MealRoutine.parseFoods(foodsText).map { $0.name.lowercased() })
        var seen = Set<String>()
        return (favourites + recent).filter { !typed.contains($0.lowercased()) && seen.insert($0.lowercased()).inserted }
    }

    private func add(_ name: String) {
        foodsText = foodsText.isEmpty || foodsText.hasSuffix("\n") ? foodsText + name : foodsText + "\n" + name
    }

    private func toggleFavourite(_ name: String) {
        let settings = context.settings()
        if let i = settings.favoriteFoods.firstIndex(of: name) {
            settings.favoriteFoods.remove(at: i)
        } else {
            settings.favoriteFoods.append(name)
        }
    }

    private func load() {
        recent = context.recentFoods()
        let windows = context.settings().goals.mealWindows
        if case .new(let day, let preset) = target {
            type = preset ?? Self.guessType(for: TimeOfDay(of: .now, in: .current), windows: windows)
            if let day, !Calendar.current.isDateInToday(day) {
                // Back-filling a past day: start at the middle of that meal's window.
                let w = windows[type] ?? MealWindow(start: TimeOfDay(12), end: TimeOfDay(12))
                time = TimeOfDay(0, (w.start.minutes + w.end.minutes) / 2).on(day, in: .current)
            }
            return
        }
        guard case .edit(let meal) = target else { return }
        type = meal.mealType
        customName = meal.customName ?? ""
        time = meal.timestamp
        foodsText = meal.sortedFoods.map { ParsedFood(name: $0.foodName, grams: $0.grams).line }.joined(separator: "\n")
        notes = meal.notes
        rating = meal.qualityRating ?? 0
    }

    private func save() {
        let foods = MealRoutine.parseFoods(foodsText)
        let meal: Meal
        switch target {
        case .new:
            meal = context.logMeal(type, foods: foods, at: time, notes: notes)
        case .edit(let existing):
            meal = existing
            meal.mealType = type
            if meal.timestamp != time {
                meal.timestamp = time
                meal.day = DayKey.of(time, calendar: .current)
                meal.timeZoneID = TimeZone.current.identifier
            }
            meal.notes = notes
            for food in meal.foods { context.delete(food) }
            for food in foods {
                let entry = FoodEntry(name: food.name, grams: food.grams)
                context.insert(entry)
                entry.meal = meal
            }
        }
        meal.customName = type == .custom && !customName.isEmpty ? customName : nil
        meal.qualityRating = rating == 0 ? nil : rating
        meal.updatedAt = .now
        dismiss()
    }

    /// The meal whose window is nearest to now.
    static func guessType(for now: TimeOfDay, windows: [MealType: MealWindow]) -> MealType {
        windows.min { a, b in
            abs(now.signedMinutes(to: TimeOfDay(0, (a.value.start.minutes + a.value.end.minutes) / 2)))
                < abs(now.signedMinutes(to: TimeOfDay(0, (b.value.start.minutes + b.value.end.minutes) / 2)))
        }?.key ?? .snack
    }
}
