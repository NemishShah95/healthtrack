import Foundation
import Observation

/// The latest Health data, shared by every screen. One query covers Today, Trends and Weekly.
@MainActor
@Observable
final class HealthStore {
    /// 90-day trends plus a previous period to compare against.
    static let historyDays = 120

    private(set) var snapshot = HealthSnapshot()
    private(set) var access: HealthAccess = .notRequested
    private(set) var isLoading = false
    let provider: any HealthDataProvider

    init(provider: any HealthDataProvider) {
        self.provider = provider
    }

    func refresh(now: Date = .now, calendar: Calendar = .current) async {
        isLoading = true
        defer { isLoading = false }
        access = await provider.accessState()
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -Self.historyDays, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return }
        snapshot = await provider.snapshot(from: start, to: end, calendar: calendar)
    }

    func requestAccess() async {
        try? await provider.requestAuthorization()
        await refresh()
    }
}
