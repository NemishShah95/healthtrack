import Foundation
@testable import HealthTrack

/// Fixed calendar so tests don't depend on the machine's time zone. London has DST (ends 2026-10-25).
func calendar(_ tz: String = "Europe/London", firstWeekday: Int = 2) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: tz)!
    c.firstWeekday = firstWeekday
    return c
}

/// "2026-10-24" or "2026-10-24 23:10", local to `cal`.
func date(_ s: String, _ cal: Calendar = calendar()) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = cal
    f.timeZone = cal.timeZone
    f.dateFormat = s.count > 10 ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
    return f.date(from: s)!
}
