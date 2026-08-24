import XCTest
@testable import AppStoreAnalyticsCLI

final class GranularityTests: XCTestCase {

    func testParsesTheThreeApiValues() {
        XCTAssertEqual(Granularity.parse("DAILY"), .daily)
        XCTAssertEqual(Granularity.parse("WEEKLY"), .weekly)
        XCTAssertEqual(Granularity.parse("MONTHLY"), .monthly)
    }

    func testParsingIsCaseInsensitiveAndTrimsWhitespace() {
        XCTAssertEqual(Granularity.parse("daily"), .daily)
        XCTAssertEqual(Granularity.parse("Weekly"), .weekly)
        XCTAssertEqual(Granularity.parse("  MONTHLY \n"), .monthly)
    }

    func testUnknownValueDoesNotParse() {
        XCTAssertNil(Granularity.parse("HOURLY"))
        XCTAssertNil(Granularity.parse("YEARLY"))
        XCTAssertNil(Granularity.parse(""))
    }

    func testMatchesInstanceGranularityCaseInsensitively() {
        XCTAssertTrue(Granularity.daily.matches(instanceGranularity: "DAILY"))
        XCTAssertTrue(Granularity.daily.matches(instanceGranularity: "daily"))
        XCTAssertFalse(Granularity.daily.matches(instanceGranularity: "WEEKLY"))
        XCTAssertFalse(Granularity.daily.matches(instanceGranularity: "MONTHLY"))
    }

    /// `APIClient` substitutes "UNKNOWN" when the API omits the attribute. Such
    /// an instance must not be folded into a DAILY-only download — the whole
    /// point of the filter is that the result is summable.
    func testUnknownInstanceGranularityMatchesNothing() {
        for granularity in Granularity.allCases {
            XCTAssertFalse(granularity.matches(instanceGranularity: "UNKNOWN"))
        }
    }

    func testAllCasesCoversEveryApiValue() {
        XCTAssertEqual(Granularity.allCases.map(\.rawValue), ["DAILY", "WEEKLY", "MONTHLY"])
    }
}
