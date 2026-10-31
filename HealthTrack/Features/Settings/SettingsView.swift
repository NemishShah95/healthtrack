import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Settings", systemImage: "gearshape",
                                   description: Text("Goals, reminders, backup and app installation."))
                .navigationTitle("Settings")
        }
    }
}
