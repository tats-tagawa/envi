import Foundation

enum ModifiedDateOrder: String, CaseIterable, Identifiable {
    case yearMonthDay
    case monthDayYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yearMonthDay: "yyyy-MM-dd"
        case .monthDayYear: "MM-dd-yyyy"
        }
    }

    static let storageKey = "modifiedDateOrder"
}

enum ModifiedDateFormat {
    static let use24HourKey = "modifiedDateUse24Hour"

    /// Formats a note's modified date for the list column.
    /// - Within 6 hours: relative ("4 hours 4 minutes ago")
    /// - Today / Yesterday: labeled day + time
    /// - Older: absolute date + time
    static func string(
        for date: Date,
        now: Date = .now,
        order: ModifiedDateOrder = .yearMonthDay,
        use24Hour: Bool = false,
        calendar: Calendar = .current
    ) -> String {
        let age = now.timeIntervalSince(date)
        if age >= 0, age < 6 * 60 * 60 {
            return relativeString(age: age)
        }

        let time = timeString(date, use24Hour: use24Hour)
        if calendar.isDateInToday(date) {
            return "Today \(time)"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday \(time)"
        }

        return "\(dateString(date, order: order)) \(time)"
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
        let hourPart = hours == 1 ? "1 hour" : "\(hours) hours"
        if minutes == 0 {
            return "\(hourPart) ago"
        }
        let minutePart = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        return "\(hourPart) \(minutePart) ago"
    }

    private static func dateString(_ date: Date, order: ModifiedDateOrder) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        switch order {
        case .yearMonthDay:
            formatter.dateFormat = "yyyy-MM-dd"
        case .monthDayYear:
            formatter.dateFormat = "MM-dd-yyyy"
        }
        return formatter.string(from: date)
    }

    private static func timeString(_ date: Date, use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
}
