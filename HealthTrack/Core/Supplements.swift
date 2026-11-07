import Foundation

enum SupplementStatus: String, Codable, CaseIterable, Sendable {
    case pending, taken, skipped, missed
}

/// What the vitamin dropdowns offer ("Other…" covers anything else).
enum VitaminCatalog {
    static let names = ["Vitamin D", "Vitamin C", "Vitamin B12", "Vitamin B complex", "Multivitamin", "Magnesium",
                        "Zinc", "Iron", "Calcium", "Omega-3", "Folic acid", "Vitamin K2", "Creatine", "Probiotic",
                        "Electrolytes", "Ashwagandha"]
    static let doses = ["1 tablet", "2 tablets", "1 capsule", "2 capsules", "1 gummy", "1 scoop", "5 ml",
                        "15 mg", "200 mg", "250 mg", "500 mg", "1000 mg", "1000 IU", "2000 IU", "5000 IU", "60,000 IU"]
}

enum DayPart: String, Codable, CaseIterable, Sendable {
    case morning, afternoon, evening

    var defaultTime: TimeOfDay {
        switch self {
        case .morning: .init(8)
        case .afternoon: .init(13)
        case .evening: .init(20)
        }
    }
}

/// When a supplement is due. Empty `weekdays` means every day.
/// Weekdays use Calendar numbering: 1 = Sunday … 7 = Saturday.
struct SupplementRule: Sendable {
    var weekdays: Set<Int>
    var startDate: Date
    var endDate: Date?
    var isActive: Bool

    func isScheduled(on day: Date, calendar: Calendar) -> Bool {
        guard isActive else { return false }
        let d = calendar.startOfDay(for: day)
        if d < calendar.startOfDay(for: startDate) { return false }
        if let endDate, d > calendar.startOfDay(for: endDate) { return false }
        return weekdays.isEmpty || weekdays.contains(calendar.component(.weekday, from: d))
    }
}

/// Adherence works on stored log statuses, not on the current schedule,
/// so pausing or editing a supplement never rewrites past history.
enum SupplementAdherence {
    /// A dose still pending after its day ended counts as missed.
    static func resolved(_ status: SupplementStatus, scheduledDay: Date, today: Date, calendar: Calendar) -> SupplementStatus {
        status == .pending && calendar.startOfDay(for: scheduledDay) < calendar.startOfDay(for: today) ? .missed : status
    }

    /// Taken ÷ scheduled. Skipped counts as not taken. nil when nothing was scheduled.
    static func rate(_ statuses: some Collection<SupplementStatus>) -> Double? {
        statuses.isEmpty ? nil : Double(statuses.filter { $0 == .taken }.count) / Double(statuses.count)
    }

    /// Consecutive days, newest first, on which everything scheduled was taken.
    /// Days with nothing scheduled are ignored. Today doesn't break the streak while doses are still pending.
    static func streak(daysNewestFirst: [[SupplementStatus]]) -> Int {
        var streak = 0
        for (i, day) in daysNewestFirst.enumerated() where !day.isEmpty {
            if day.allSatisfy({ $0 == .taken }) {
                streak += 1
            } else if i == 0 && day.allSatisfy({ $0 == .taken || $0 == .pending }) {
                continue
            } else {
                break
            }
        }
        return streak
    }

    /// The supplement with the most missed or skipped doses (ties: alphabetical). nil if none.
    static func mostMissed(_ logs: [(name: String, status: SupplementStatus)]) -> String? {
        var counts: [String: Int] = [:]
        for log in logs where log.status == .missed || log.status == .skipped {
            counts[log.name, default: 0] += 1
        }
        return counts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }
}
