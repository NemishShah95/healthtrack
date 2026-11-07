import SwiftData
import SwiftUI

/// One database connection for the app and for Siri / Shortcuts actions, so a voice log shows up on screen at once.
@MainActor
enum AppStore {
    static let container: Result<ModelContainer, Error> = Result {
        try Persistence.makeContainer(inMemory: AppEnvironment.arguments.contains("-inMemoryStore"))
    }
}

@main
struct HealthTrackApp: App {
    private let container: Result<ModelContainer, Error>
    @State private var health = HealthStore(provider: AppEnvironment.makeHealthProvider())

    init() {
        let args = AppEnvironment.arguments
        container = AppStore.container
        Self.styleNavigationBars()
        if case .success(let c) = container {
            if args.contains("-seedSampleData") { SampleData.seedIfEmpty(c.mainContext) }
            if args.contains("-skipOnboarding") { c.mainContext.settings().hasCompletedOnboarding = true }
        }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let c):
                RootView()
                    .modelContainer(c)
                    .environment(health)
            case .failure(let error):
                DatabaseErrorView(error: error)
            }
        }
    }

    /// Light-weight large titles, as in the design. Dynamic Type still scales them.
    private static func styleNavigationBars() {
        let large = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 34, weight: .light))
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: large, .foregroundColor: UIColor(Palette.text)]
        bar.titleTextAttributes = [.foregroundColor: UIColor(Palette.text)]
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HealthStore.self) private var health
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "sun.max") }
            TrainingView().tabItem { Label("Training", systemImage: "figure.strengthtraining.traditional") }
            TrendsView().tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
            WeeklyView().tabItem { Label("Weekly", systemImage: "calendar") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Palette.lime)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await becameActive() } }
        }
        .sheet(isPresented: $showOnboarding) { OnboardingView() }
    }

    /// Runs on launch and every return to the foreground. Everything here is idempotent.
    private func becameActive() async {
        let settings = context.settings()
        ReinstallTracker.recordLaunch(settings)
        context.syncSupplementLogs()
        try? context.save()
        showOnboarding = !settings.hasCompletedOnboarding
        await health.refresh()
        await Reminders.reschedule(context)
        HealthTrackShortcuts.updateAppShortcutParameters()   // "Log <vitamin>" knows your vitamins
    }
}

/// Shown instead of crashing if the database can't be opened. Nothing is deleted.
struct DatabaseErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("HealthTrack couldn't open your data", systemImage: "externaldrive.badge.exclamationmark")
                .foregroundStyle(Palette.text)
        } description: {
            Text("""
            Nothing has been deleted. Please don't delete the app. \
            Reinstall it from Xcode on your personal Mac, and keep this message for troubleshooting:

            \(error.localizedDescription)
            """)
        }
        .background(AppBackground())
        .preferredColorScheme(.dark)
    }
}
