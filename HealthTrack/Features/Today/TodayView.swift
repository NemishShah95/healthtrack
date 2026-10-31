import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Am I having a healthy day?", systemImage: "sun.max",
                                   description: Text("Your daily cards will appear here."))
                .navigationTitle("Today")
        }
    }
}
