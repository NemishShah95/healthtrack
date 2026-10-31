import SwiftData
import SwiftUI

@main
struct HealthTrackApp: App {
    private let container: Result<ModelContainer, Error>
    private let health = AppEnvironment.makeHealthProvider()

    init() {
        let args = AppEnvironment.arguments
        container = Result { try Persistence.makeContainer(inMemory: args.contains("-inMemoryStore")) }
        if case .success(let c) = container, args.contains("-seedSampleData") {
            SampleData.seedIfEmpty(c.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let c):
                RootView()
                    .modelContainer(c)
                    .environment(\.health, health)
            case .failure(let error):
                DatabaseErrorView(error: error)
            }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "sun.max") }
            LogView().tabItem { Label("Log", systemImage: "plus.circle") }
            TrendsView().tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
            WeeklyView().tabItem { Label("Weekly", systemImage: "calendar") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

/// Shown instead of crashing if the database can't be opened. Nothing is deleted.
struct DatabaseErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("HealthTrack couldn't open your data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("""
            Nothing has been deleted. Please don't delete the app. \
            Reinstall it from Xcode on your personal Mac, and keep this message for troubleshooting:

            \(error.localizedDescription)
            """)
        }
    }
}
