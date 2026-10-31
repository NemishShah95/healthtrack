import SwiftData
import UserNotifications

/// Local notifications only. Rebuilt from settings each time anything changes; nothing repeats unless
/// the user turned it on. Permission is requested only once at least one reminder is enabled.
@MainActor
enum Reminders {
    static func reschedule(_ context: ModelContext, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let settings = context.settings()
        let r = settings.reminders
        let goals = settings.goals
        var requests: [UNNotificationRequest] = []

        func add(_ id: String, _ title: String, _ body: String, at t: TimeOfDay, weekday: Int? = nil) {
            var when = DateComponents()
            when.hour = t.hour
            when.minute = t.minute
            when.weekday = weekday
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            requests.append(UNNotificationRequest(identifier: id, content: content,
                                                  trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
        }

        if r.meals {
            for type in MealType.targeted {
                if let w = goals.mealWindows[type] {
                    add("meal.\(type.rawValue)", "\(type.rawValue.capitalized) time", "Log it with one tap in HealthTrack.", at: w.start)
                }
            }
        }
        if r.water {
            for (i, t) in r.waterTimes.enumerated() { add("water.\(i)", "Water", "Time for a glass. One tap to log it.", at: t) }
        }
        if r.bedtime {
            add("bedtime", "Bedtime in 30 minutes", "Your target is \(goals.bedtime.formatted()).", at: TimeOfDay(0, goals.bedtime.minutes - 30))
        }
        if r.checkIn { add("checkin", "Daily check-in", "Energy, mood, stress: three taps.", at: r.checkInTime) }
        if r.backup { add("backup", "Back up HealthTrack", "Settings → Data & Backup → Export JSON.", at: TimeOfDay(10), weekday: 1) }

        for s in (try? context.fetch(FetchDescriptor<Supplement>())) ?? [] where s.active {
            for sch in s.schedules where sch.reminderEnabled && (sch.endDate ?? .distantFuture) >= now {
                guard let t = sch.reminderTime else { continue }
                let body = s.dosageText.isEmpty ? "Tap to mark it taken." : s.dosageText
                if sch.daysOfWeek.isEmpty || sch.daysOfWeek.count == 7 {
                    add("supplement.\(sch.id)", s.name, body, at: t)
                } else {
                    for d in sch.daysOfWeek { add("supplement.\(sch.id).\(d)", s.name, body, at: t, weekday: d) }
                }
            }
        }

        if settings.refreshReminderEnabled, let next = ReinstallTracker.nextRefresh(settings, now: now) {
            let fireAt = TimeOfDay(9).on(next, in: .current)
            if fireAt > now {
                let content = UNMutableNotificationContent()
                content.title = "HealthTrack app refresh due tomorrow."
                content.body = "Connect your iPhone to your personal Mac and run the project from Xcode."
                let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
                requests.append(UNNotificationRequest(identifier: "refresh", content: content,
                                                      trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
            }
        }

        guard !requests.isEmpty,
              (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        for request in requests { try? await center.add(request) }
    }
}
