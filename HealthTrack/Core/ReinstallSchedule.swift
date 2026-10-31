import Foundation

/// Free Personal Team builds stop launching ~7 days after signing. HealthTrack suggests a refresh
/// on day 6 and starts warning 2 days before.
enum RefreshStatus: Equatable, Sendable {
    case ok
    case dueSoon(Date)
    case dueToday
}

enum ReinstallSchedule {
    static let refreshAfterDays = 6
    static let warningDays = 2

    /// Last refresh + 6 days, pulled earlier if the signing profile expires sooner than that.
    static func nextSuggestedRefresh(lastRefresh: Date, profileExpiration: Date?, calendar: Calendar) -> Date {
        let byDays = calendar.date(byAdding: .day, value: refreshAfterDays, to: lastRefresh) ?? lastRefresh
        guard let profileExpiration,
              let dayBefore = calendar.date(byAdding: .day, value: -1, to: profileExpiration) else { return byDays }
        return min(byDays, dayBefore)
    }

    static func status(now: Date, nextSuggested: Date, calendar: Calendar) -> RefreshStatus {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: nextSuggested)).day ?? 0
        if days <= 0 { return .dueToday }
        if days <= warningDays { return .dueSoon(nextSuggested) }
        return .ok
    }
}
