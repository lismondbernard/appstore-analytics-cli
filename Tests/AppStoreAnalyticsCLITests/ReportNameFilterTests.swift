import XCTest
@testable import AppStoreAnalyticsCLI

final class ReportNameFilterTests: XCTestCase {

    // The names Apple actually returns for an ONGOING request.
    private let liveReportNames = [
        "App Store Discovery and Engagement Standard",
        "App Store Discovery and Engagement Detailed",
        "App Downloads Standard",
        "App Downloads Detailed",
        "App Store Installation and Deletion Standard",
        "App Sessions Standard",
        "App Store Web Preview Engagement Standard",
        "Platform App Installs"
    ]

    private func matching(_ filter: String) -> [String] {
        liveReportNames.filter { ReportNameFilter.matches($0, filter: filter) }
    }

    func testExactNameSelectsOneReport() {
        XCTAssertEqual(matching("App Downloads Standard"), ["App Downloads Standard"])
    }

    func testPartialNameSelectsEveryCutOfThatReport() {
        XCTAssertEqual(matching("discovery"), [
            "App Store Discovery and Engagement Standard",
            "App Store Discovery and Engagement Detailed"
        ])
    }

    func testStandardSelectsTheStandardCutAcrossReports() {
        XCTAssertEqual(matching("Standard").count, 5)
        XCTAssertFalse(matching("Standard").contains("App Downloads Detailed"))
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(matching("APP DOWNLOADS STANDARD"), ["App Downloads Standard"])
    }

    func testSurroundingWhitespaceIsIgnored() {
        XCTAssertEqual(matching("  App Downloads Standard \n"), ["App Downloads Standard"])
    }

    /// The regression this filter exists for: `ReportType` raw values name a
    /// different catalogue and match nothing here. Previously such an argument
    /// disabled filtering entirely and downloaded every instance; now it finds
    /// nothing, which the callers report as an error.
    func testReportTypeRawValuesMatchNothingRatherThanEverything() {
        XCTAssertTrue(matching("APP_STORE_PRODUCT_PAGE_VIEWS").isEmpty)
        XCTAssertTrue(matching("App Store Product Page Views").isEmpty)
    }

    func testUnknownNameMatchesNothing() {
        XCTAssertTrue(matching("Subscription Retention").isEmpty)
    }

    func testMissingReportNameNeverMatches() {
        XCTAssertFalse(ReportNameFilter.matches(nil, filter: "discovery"))
    }

    /// An empty filter is treated as "no filter" rather than "match nothing",
    /// so `--report-type ""` degrades to an unfiltered download.
    func testEmptyFilterMatchesEverything() {
        XCTAssertEqual(matching(""), liveReportNames)
        XCTAssertEqual(matching("   "), liveReportNames)
        XCTAssertTrue(ReportNameFilter.matches(nil, filter: ""))
    }
}
