import SwiftUI

struct LogView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Log", systemImage: "plus.circle",
                                   description: Text("Meals, water, supplements and check-ins."))
                .navigationTitle("Log")
        }
    }
}
