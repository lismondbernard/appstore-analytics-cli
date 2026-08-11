import Foundation

/// Report-date arithmetic for Sales and Trends.
///
/// Apple wants a different `filter[reportDate]` format per frequency, and only
/// accepts periods that have actually closed — asking for today's daily report
/// or the current month returns a 404, which is indistinguishable from "no
/// sales" unless we avoid asking in the first place.
enum SalesReportPeriod {
    enum Frequency: String, CaseIterable {
        case daily = "DAILY"
        case weekly = "WEEKLY"
        case monthly = "MONTHLY"
        case yearly = "YEARLY"

        /// Format Apple expects for `filter[reportDate]`.
        var dateFormat: String {
            switch self {
            case .daily, .weekly: return "yyyy-MM-dd"
            case .monthly: return "yyyy-MM"
            case .yearly: return "yyyy"
            }
        }
    }

    /// The `count` most recent closed periods, oldest first.
    ///
    /// `now` is injectable so the arithmetic is testable without waiting for
    /// the calendar to move.
    static func recent(
        _ count: Int,
        frequency: Frequency,
        now: Date = Date(),
        calendar: Calendar = {
            // Apple's report dates are in UTC; a local calendar rolls the day
            // over at the wrong moment for anyone west of Greenwich.
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            return calendar
        }()
    ) -> [String] {
        guard count > 0 else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = frequency.dateFormat
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let anchor = mostRecentClosedPeriod(frequency: frequency, now: now, calendar: calendar) else {
            return []
        }

        let component: Calendar.Component
        switch frequency {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly: component = .year
        }

        return (0..<count).compactMap { offset -> String? in
            guard let date = calendar.date(byAdding: component, value: -offset, to: anchor) else { return nil }
            return formatter.string(from: date)
        }.reversed()
    }

    private static func mostRecentClosedPeriod(
        frequency: Frequency,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))

        case .weekly:
            // Apple's weekly reports are labelled with the Sunday that ends
            // them, so step back to the most recent Sunday that has passed.
            let startOfToday = calendar.startOfDay(for: now)
            let weekday = calendar.component(.weekday, from: startOfToday) // 1 = Sunday
            let daysSinceSunday = weekday - 1
            let lastSunday = calendar.date(byAdding: .day, value: -daysSinceSunday, to: startOfToday)
            // Today being Sunday means this week has not closed yet.
            guard let lastSunday else { return nil }
            return daysSinceSunday == 0
                ? calendar.date(byAdding: .day, value: -7, to: lastSunday)
                : lastSunday

        case .monthly:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            guard let startOfMonth else { return nil }
            return calendar.date(byAdding: .month, value: -1, to: startOfMonth)

        case .yearly:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))
            guard let startOfYear else { return nil }
            return calendar.date(byAdding: .year, value: -1, to: startOfYear)
        }
    }
}
