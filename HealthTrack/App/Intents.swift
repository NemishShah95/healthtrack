import AppIntents
import SwiftData

// "Hey Siri, log 500 ml of water in HealthTrack." Also in the Shortcuts app, Spotlight and the Action button.
// Runs in the app, on the same database the screens use. Idea borrowed from Helios's voice capture (MIT).

enum WaterAmount: Int, AppEnum {
    case ml250 = 250, ml500 = 500, ml750 = 750

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Water amount"
    static let caseDisplayRepresentations: [WaterAmount: DisplayRepresentation] = [
        .ml250: "250 ml", .ml500: "500 ml", .ml750: "750 ml",
    ]
}

enum ProteinAmount: Int, AppEnum {
    case g10 = 10, g20 = 20, g30 = 30

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Protein amount"
    static let caseDisplayRepresentations: [ProteinAmount: DisplayRepresentation] = [
        .g10: "10 grams", .g20: "20 grams", .g30: "30 grams",
    ]
}

enum MealChoice: String, AppEnum {
    case breakfast, lunch, dinner, snack

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Meal"
    static let caseDisplayRepresentations: [MealChoice: DisplayRepresentation] = [
        .breakfast: "breakfast", .lunch: "lunch", .dinner: "dinner", .snack: "a snack",
    ]
}

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log water"
    static let description = IntentDescription("Adds water to today in HealthTrack.")

    @Parameter(title: "Amount", default: .ml250) var amount: WaterAmount

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = try AppStore.container.get().mainContext
        guard context.logWater(amount.rawValue) != nil else { return .result(dialog: "That was already logged a moment ago.") }
        try context.save()
        let today = Calendar.current.startOfDay(for: .now)
        let total = context.water(from: today, to: today.addingTimeInterval(86_400)).reduce(0) { $0 + $1.amountML }
        let target = context.settings().goals.waterTargetML
        return .result(dialog: "Logged \(amount.rawValue) ml. \(Hydration.progressText(totalML: total, targetML: target)) today.")
    }
}

struct LogProteinIntent: AppIntent {
    static let title: LocalizedStringResource = "Log protein"
    static let description = IntentDescription("Adds protein to today in HealthTrack.")

    @Parameter(title: "Amount", default: .g20) var amount: ProteinAmount

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = try AppStore.container.get().mainContext
        guard context.logProtein(amount.rawValue) != nil else { return .result(dialog: "That was already logged a moment ago.") }
        try context.save()
        let today = Calendar.current.startOfDay(for: .now)
        let total = context.protein(from: today, to: today.addingTimeInterval(86_400)).reduce(0) { $0 + $1.grams }
        return .result(dialog: "Logged \(amount.rawValue) g. \(total) of \(context.settings().goals.proteinTargetGrams) g today.")
    }
}

struct LogMealIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a meal"
    static let description = IntentDescription("Logs a meal now in HealthTrack.")

    @Parameter(title: "Meal") var meal: MealChoice

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = try AppStore.container.get().mainContext
        context.logMeal(MealType(rawValue: meal.rawValue) ?? .snack)
        try context.save()
        return .result(dialog: "Logged \(meal.rawValue) at \(Date.now.formatted(date: .omitted, time: .shortened)).")
    }
}

/// One of your vitamins, so Siri can say "Log Vitamin D".
struct VitaminEntity: AppEntity {
    let id: UUID
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Vitamin"
    static let defaultQuery = VitaminQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct VitaminQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [VitaminEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [VitaminEntity] { all() }

    @MainActor
    private func all() -> [VitaminEntity] {
        let supplements = (try? AppStore.container.get().mainContext.fetch(FetchDescriptor<Supplement>(sortBy: [SortDescriptor(\.name)]))) ?? []
        return supplements.filter(\.active).map { VitaminEntity(id: $0.id, name: $0.name) }
    }
}

struct LogVitaminIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a vitamin"
    static let description = IntentDescription("Marks a vitamin as taken now: today's scheduled dose if it's still open, otherwise an extra.")

    @Parameter(title: "Vitamin") var vitamin: VitaminEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = try AppStore.container.get().mainContext
        let id = vitamin.id
        guard let supplement = try context.fetch(FetchDescriptor<Supplement>(predicate: #Predicate { $0.id == id })).first else {
            return .result(dialog: "I couldn't find that vitamin in HealthTrack.")
        }
        guard context.takeVitamin(supplement) else { return .result(dialog: "That was already logged a moment ago.") }
        try context.save()
        return .result(dialog: "Logged \(supplement.name) as taken.")
    }
}

struct HealthTrackShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogWaterIntent(),
                    phrases: ["Log water in \(.applicationName)", "Log \(\.$amount) of water in \(.applicationName)"],
                    shortTitle: "Log water", systemImageName: "drop.fill")
        AppShortcut(intent: LogVitaminIntent(),
                    phrases: ["Log a vitamin in \(.applicationName)", "Log \(\.$vitamin) in \(.applicationName)",
                              "I took \(\.$vitamin) in \(.applicationName)"],
                    shortTitle: "Log vitamin", systemImageName: "pills.fill")
        AppShortcut(intent: LogProteinIntent(),
                    phrases: ["Log protein in \(.applicationName)", "Log \(\.$amount) of protein in \(.applicationName)"],
                    shortTitle: "Log protein", systemImageName: "fork.knife.circle")
        AppShortcut(intent: LogMealIntent(),
                    phrases: ["Log a meal in \(.applicationName)", "Log \(\.$meal) in \(.applicationName)"],
                    shortTitle: "Log meal", systemImageName: "fork.knife")
    }
}
