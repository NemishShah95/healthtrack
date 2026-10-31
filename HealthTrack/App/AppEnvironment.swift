import SwiftUI

enum AppEnvironment {
    /// Launch arguments (set in the Xcode scheme or by UI tests):
    /// `-mockHealth <full|empty|denied|partial|noStages|unavailable>`, `-seedSampleData`, `-inMemoryStore`.
    static let arguments = ProcessInfo.processInfo.arguments

    static func makeHealthProvider() -> any HealthDataProvider {
        if let raw = UserDefaults.standard.string(forKey: "mockHealth"),
           let scenario = MockHealthDataProvider.Scenario(rawValue: raw) {
            return MockHealthDataProvider(scenario: scenario)
        }
        #if targetEnvironment(simulator)
        return MockHealthDataProvider(scenario: .full)   // the simulator has no Health data
        #else
        return HealthKitProvider()
        #endif
    }
}
