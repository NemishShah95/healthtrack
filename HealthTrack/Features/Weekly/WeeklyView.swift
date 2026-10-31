import SwiftUI

struct WeeklyView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Weekly Review", systemImage: "calendar",
                                   description: Text("Your week at a glance."))
                .navigationTitle("Weekly")
        }
    }
}
