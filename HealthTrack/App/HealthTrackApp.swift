import SwiftUI

@main
struct HealthTrackApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
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
