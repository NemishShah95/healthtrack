import SwiftData
import SwiftUI

/// Everything about one day's meals: quick log, add with foods, edit, repeat, history.
struct MealsDetail: View {
    @Environment(\.modelContext) private var context
    @Query private var meals: [Meal]
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]
    @State private var editing: MealEditor.Target?
    let day: Date

    init(day: Date) {
        let key = DayKey.of(day, calendar: .current)
        self.day = day
        _meals = Query(filter: #Predicate<Meal> { $0.day == key }, sort: \.timestamp)
    }

    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach([MealType.breakfast, .lunch, .dinner, .snack], id: \.self) { type in
                            Button(type.rawValue.capitalized) {
                                if isToday { context.logMeal(type) } else { editing = .new(day: day, type: type) }
                            }
                            .accessibilityLabel("Log \(type.rawValue)")
                        }
                        ForEach(savedMeals) { saved in
                            Button(saved.name, systemImage: "star") {
                                context.logSavedMeal(saved, at: Calendar.current.timestamp(on: day))
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                Button("Add meal with foods…", systemImage: "square.and.pencil") { editing = .new(day: day, type: nil) }
            } footer: {
                Text(isToday ? "One tap logs a meal now. Add foods and grams only when you want the detail."
                             : "Pick a meal to log it for this day.")
            }

            Section("Logged") {
                if meals.isEmpty { Text("No meals yet.").foregroundStyle(.secondary) }
                ForEach(meals) { meal in
                    MealRow(meal: meal)
                        .contentShape(.rect)
                        .onTapGesture { editing = .edit(meal) }
                        .contextMenu { MealActions(meal: meal) }
                }
                .onDelete { for i in $0 { context.delete(meals[i]) } }
            }

            Section {
                NavigationLink("Meal history") { MealHistoryView() }
            }
        }
        .navigationTitle(isToday ? "Meals" : "Meals · \(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
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
