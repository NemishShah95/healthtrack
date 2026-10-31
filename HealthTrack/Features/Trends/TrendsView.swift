import SwiftUI

struct TrendsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Trends", systemImage: "chart.xyaxis.line",
                                   description: Text("7, 30 and 90-day charts."))
                .navigationTitle("Trends")
        }
    }
}
