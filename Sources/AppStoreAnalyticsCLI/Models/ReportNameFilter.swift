import Foundation

/// Matches a `--report-type` argument against the report names the Analytics
/// API actually returns.
///
/// Apple names its analytics reports things like "App Store Discovery and
/// Engagement Standard", "App Downloads Standard" and "Platform App Installs".
/// Those names are unrelated to `ReportType`'s raw values
/// (`APP_STORE_PRODUCT_PAGE_VIEWS` and friends), which describe the older
/// report catalogue that `list-report-types` prints. Matching an argument
/// against `ReportType` therefore never matched a live report, and because the
/// filter was gated on `ReportType(rawValue:)` succeeding, anything else
/// skipped filtering altogether and quietly downloaded every instance.
enum ReportNameFilter {
    /// Case- and whitespace-insensitive substring match, so `discovery` selects
    /// both the Standard and Detailed cuts of the discovery report while
    /// `App Downloads Standard` selects exactly one.
    static func matches(_ reportName: String?, filter: String) -> Bool {
        let needle = normalized(filter)
        guard !needle.isEmpty else { return true }
        guard let reportName else { return false }
        return normalized(reportName).contains(needle)
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
