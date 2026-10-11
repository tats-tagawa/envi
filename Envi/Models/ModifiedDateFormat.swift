import Foundation

enum ModifiedDateOrder: String, CaseIterable, Identifiable {
    case monthDayYear
    case yearMonthDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthDayYear: "Oct 4, 2026"
        case .yearMonthDay: "2026 Oct 4"
        }
    }

    static let storageKey = "modifiedDateOrder"
}

enum ModifiedDateFormat {
    static let use24HourKey = "modifiedDateUse24Hour"

    /// Formats a note's modified date for the list column.
    /// - Within 6 hours: relative ("Just now", "4 minutes ago")
    /// - Today / Yesterday: labeled day + time
    /// - Older: medium date + time (`Oct 4` / `Oct 4, 2026`)
    static func string(
        for date: Date,
        now: Date = .now,
        order: ModifiedDateOrder = .monthDayYear,
        use24Hour: Bool = false,
        calendar: Calendar = .current
    ) -> String {
        let age = now.timeIntervalSince(date)
        if age >= 0, age < 6 * 60 * 60 {
            return relativeString(age: age)
        }

        let timeZone = calendar.timeZone
        let time = timeString(date, use24Hour: use24Hour, timeZone: timeZone)
        if calendar.isDateInToday(date) {
            return "Today \(time)"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday \(time)"
        }

        return "\(dateString(date, order: order, now: now, calendar: calendar)) \(time)"
    }

    /// Full absolute timestamp for tooltips.
    static func tooltip(
        for date: Date,
        order: ModifiedDateOrder = .monthDayYear,
        use24Hour: Bool = false,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        switch order {
        case .monthDayYear:
            formatter.dateFormat = use24Hour ? "MMM d, yyyy HH:mm" : "MMM d, yyyy h:mm a"
        case .yearMonthDay:
            formatter.dateFormat = use24Hour ? "yyyy MMM d HH:mm" : "yyyy MMM d h:mm a"
        }
        return formatter.string(from: date)
    }

    private static func relativeString(age: TimeInterval) -> String {
        let totalMinutes = Int(age / 60)
        if totalMinutes < 1 {
            return "Just now"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
        // Prefer a short relative form once past the hour mark.
        if hours == 1, minutes == 0 {
            return "1 hour ago"
        }
        if minutes == 0 {
            return "\(hours) hours ago"
        }
        if hours == 1 {
            return minutes == 1 ? "1 hour 1 minute ago" : "1 hour \(minutes) minutes ago"
        }
        let minutePart = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        return "\(hours) hours \(minutePart) ago"
    }

    private static func dateString(
        _ date: Date,
        order: ModifiedDateOrder,
        now: Date,
        calendar: Calendar
    ) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        switch order {
        case .monthDayYear:
            formatter.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        case .yearMonthDay:
            formatter.dateFormat = sameYear ? "MMM d" : "yyyy MMM d"
        }
        return formatter.string(from: date)
    }

    private static func timeString(_ date: Date, use24Hour: Bool, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
}
