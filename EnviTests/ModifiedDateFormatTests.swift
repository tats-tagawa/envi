import XCTest
@testable import Envi

final class ModifiedDateFormatTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }

    func testJustNow() {
        let now = date(year: 2026, month: 10, day: 11, hour: 16, minute: 0)
        let value = ModifiedDateFormat.string(
            for: now.addingTimeInterval(-30),
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(value, "Just now")
    }

    func testRelativeMinutes() {
        let now = date(year: 2026, month: 10, day: 11, hour: 16, minute: 0)
        let value = ModifiedDateFormat.string(
            for: now.addingTimeInterval(-5 * 60),
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(value, "5 minutes ago")
    }

    func testTodayUsesLabelAndTime() {
        let now = date(year: 2026, month: 10, day: 11, hour: 16, minute: 0)
        let earlier = date(year: 2026, month: 10, day: 11, hour: 8, minute: 30)
        let value = ModifiedDateFormat.string(
            for: earlier,
            now: now,
            order: .monthDayYear,
            use24Hour: true,
            calendar: calendar
        )
        XCTAssertEqual(value, "Today 08:30")
    }

    func testYesterdayUsesLabelAndTime() {
        let now = date(year: 2026, month: 10, day: 11, hour: 16, minute: 0)
        let yesterday = date(year: 2026, month: 10, day: 10, hour: 9, minute: 15)
        let value = ModifiedDateFormat.string(
            for: yesterday,
            now: now,
            order: .monthDayYear,
            use24Hour: true,
            calendar: calendar
        )
        XCTAssertEqual(value, "Yesterday 09:15")
    }

    func testSameYearMediumDate() {
        let now = date(year: 2026, month: 10, day: 11, hour: 16, minute: 0)
        let older = date(year: 2026, month: 3, day: 4, hour: 14, minute: 17)
        let value = ModifiedDateFormat.string(
            for: older,
            now: now,
            order: .monthDayYear,
            use24Hour: true,
            calendar: calendar
        )
        XCTAssertEqual(value, "Mar 4 14:17")
    }

    func testOtherYearIncludesYear() {
        let now = date(year: 2026, month: 10, day: 11, hour: 16, minute: 0)
        let older = date(year: 2025, month: 10, day: 4, hour: 16, minute: 17)
        let monthDay = ModifiedDateFormat.string(
            for: older,
            now: now,
            order: .monthDayYear,
            use24Hour: true,
            calendar: calendar
        )
        let yearMonth = ModifiedDateFormat.string(
            for: older,
            now: now,
            order: .yearMonthDay,
            use24Hour: true,
            calendar: calendar
        )
        XCTAssertEqual(monthDay, "Oct 4, 2025 16:17")
        XCTAssertEqual(yearMonth, "2025 Oct 4 16:17")
    }

    func testTooltipIsFullAbsolute() {
        let date = date(year: 2026, month: 10, day: 4, hour: 16, minute: 17)
        let tip = ModifiedDateFormat.tooltip(
            for: date,
            order: .monthDayYear,
            use24Hour: true,
            timeZone: calendar.timeZone
        )
        XCTAssertEqual(tip, "Oct 4, 2026 16:17")
    }
}
