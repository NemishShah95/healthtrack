import SwiftData
import SwiftUI

/// Add or edit a meal. Foods are optional, picked from a dropdown, with grams from a dropdown.
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
    @State private var foods: [ParsedFood] = []
    @State private var notes = ""
    @State private var rating = 0
    @State private var recent: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Picker("Meal", selection: $type) {
                        ForEach(MealType.allCases, id: \.self) { Text($0.rawValue.capitalized) }
                    }
                    if type == .custom { TextField("Name", text: $customName) }
                    DatePicker("Time", selection: $time)

                    Section {
                        ForEach(Array(foods.indices), id: \.self) { i in
                            if foods.indices.contains(i) { foodRow(i) }
                        }
                        .onDelete { foods.remove(atOffsets: $0) }
                        NameMenu(title: "Food name", groups: foodGroups, pick: add) {
                            Label("Add food", systemImage: "plus.circle.fill").foregroundStyle(Palette.lime)
                        }
                        .accessibilityLabel("Add food")
                    } header: {
                        Text("Foods (optional)")
                    } footer: {
                        Text("Grams are optional. Long-press a food to add it to your favourites. Swipe left to remove one.")
                    }

                    Section {
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
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
                .appRows()
            }
            .appScreen()
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

    private func foodRow(_ i: Int) -> some View {
        let name = foods[i].name
        return HStack {
            Text(name).foregroundStyle(Palette.text)
            Spacer()
            Picker("\(name) grams", selection: Binding(
                get: { foods.indices.contains(i) ? foods[i].grams : nil },
                set: { if foods.indices.contains(i) { foods[i].grams = $0 } })) {
                Text("No grams").tag(Double?.none)
                ForEach(gramOptions(including: foods[i].grams), id: \.self) { Text("\(String(format: "%g", $0)) g").tag(Double?.some($0)) }
            }
            .labelsHidden()
        }
        .contextMenu {
            Button(favourites.contains(name) ? "Remove from favourites" : "Add to favourites", systemImage: "star") { toggleFavourite(name) }
        }
    }

    /// Favourites, then recent, then common foods; each name appears once.
    private var foodGroups: [(title: String, names: [String])] {
        let fav = uniqueNames(favourites)
        let rec = uniqueNames(recent).filter { r in !fav.contains { $0.caseInsensitiveCompare(r) == .orderedSame } }
        let common = MealRoutine.commonFoods.filter { c in !(fav + rec).contains { $0.caseInsensitiveCompare(c) == .orderedSame } }
        return [("Favourites", fav), ("Recent", rec), ("Common", common)]
    }

    private func gramOptions(including current: Double?) -> [Double] {
        guard let current, !MealRoutine.gramOptions.contains(current) else { return MealRoutine.gramOptions }
        return (MealRoutine.gramOptions + [current]).sorted()
    }

    private func add(_ name: String) {
        foods.append(ParsedFood(name: name, grams: nil))
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
        foods = meal.sortedFoods.map { ParsedFood(name: $0.foodName, grams: $0.grams) }
        notes = meal.notes
        rating = meal.qualityRating ?? 0
    }

    private func save() {
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
            for (i, food) in foods.enumerated() {
                let entry = FoodEntry(name: food.name, grams: food.grams)
                entry.position = i
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
