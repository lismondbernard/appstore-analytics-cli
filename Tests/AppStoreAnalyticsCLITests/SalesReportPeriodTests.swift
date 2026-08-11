import XCTest
@testable import AppStoreAnalyticsCLI

final class SalesReportPeriodTests: XCTestCase {

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")!
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: iso)!
    }

    // MARK: - Daily

    /// Today's report does not exist yet — asking for it returns a 404 that is
    /// indistinguishable from "no sales", so the most recent daily period is
    /// always yesterday.
    func testDailyStopsAtYesterday() {
        let periods = SalesReportPeriod.recent(3, frequency: .daily, now: date("2026-08-11 09:00"), calendar: utc)

        XCTAssertEqual(periods, ["2026-08-08", "2026-08-09", "2026-08-10"])
    }

    func testPeriodsAreOldestFirst() {
        let periods = SalesReportPeriod.recent(2, frequency: .daily, now: date("2026-08-11 09:00"), calendar: utc)

        XCTAssertEqual(periods.first, "2026-08-09")
        XCTAssertEqual(periods.last, "2026-08-10")
    }

    /// A late-evening run in a western timezone must not roll the date forward
    /// into a period Apple has not closed.
    func testDailyUsesUTCNotLocalMidnight() {
        let periods = SalesReportPeriod.recent(1, frequency: .daily, now: date("2026-08-11 03:30"), calendar: utc)

        XCTAssertEqual(periods, ["2026-08-10"])
    }

    // MARK: - Weekly

    /// Apple labels a weekly report with the Sunday that closes it.
    func testWeeklyUsesMostRecentClosedSunday() {
        // 2026-08-11 is a Tuesday; the week ending Sunday 2026-08-09 has closed.
        let periods = SalesReportPeriod.recent(2, frequency: .weekly, now: date("2026-08-11 09:00"), calendar: utc)

        XCTAssertEqual(periods, ["2026-08-02", "2026-08-09"])
    }

    func testWeeklyOnASundaySkipsTheStillOpenWeek() {
        // 2026-08-09 is itself a Sunday, so the newest closed week is the prior one.
        let periods = SalesReportPeriod.recent(1, frequency: .weekly, now: date("2026-08-09 09:00"), calendar: utc)

        XCTAssertEqual(periods, ["2026-08-02"])
    }

    // MARK: - Monthly and yearly

    func testMonthlyStopsAtLastCompleteMonth() {
        let periods = SalesReportPeriod.recent(3, frequency: .monthly, now: date("2026-08-11 09:00"), calendar: utc)

        XCTAssertEqual(periods, ["2026-05", "2026-06", "2026-07"])
    }

    func testMonthlyCrossesTheYearBoundary() {
        let periods = SalesReportPeriod.recent(2, frequency: .monthly, now: date("2026-01-15 09:00"), calendar: utc)

        XCTAssertEqual(periods, ["2025-11", "2025-12"])
    }

    func testYearlyStopsAtLastCompleteYear() {
        let periods = SalesReportPeriod.recent(2, frequency: .yearly, now: date("2026-08-11 09:00"), calendar: utc)

        XCTAssertEqual(periods, ["2024", "2025"])
    }

    // MARK: - Formats and edges

    func testDateFormatMatchesAppleExpectationPerFrequency() {
        XCTAssertEqual(SalesReportPeriod.Frequency.daily.dateFormat, "yyyy-MM-dd")
        XCTAssertEqual(SalesReportPeriod.Frequency.weekly.dateFormat, "yyyy-MM-dd")
        XCTAssertEqual(SalesReportPeriod.Frequency.monthly.dateFormat, "yyyy-MM")
        XCTAssertEqual(SalesReportPeriod.Frequency.yearly.dateFormat, "yyyy")
    }

    func testZeroOrNegativeCountReturnsNothing() {
        XCTAssertTrue(SalesReportPeriod.recent(0, frequency: .daily, now: date("2026-08-11 09:00"), calendar: utc).isEmpty)
        XCTAssertTrue(SalesReportPeriod.recent(-3, frequency: .daily, now: date("2026-08-11 09:00"), calendar: utc).isEmpty)
    }
}
