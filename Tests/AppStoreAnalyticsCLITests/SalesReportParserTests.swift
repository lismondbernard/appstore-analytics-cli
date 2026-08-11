import XCTest
@testable import AppStoreAnalyticsCLI

final class SalesReportParserTests: XCTestCase {

    /// Trimmed to the columns this tool reads, in Apple's order and with the
    /// CRLF line endings the real report uses.
    private let report = [
        "Provider\tSKU\tTitle\tProduct Type Identifier\tUnits\tDeveloper Proceeds\tCountry Code\tCurrency of Proceeds\tBegin Date",
        "APPLE\tTP_UNLOCK\tTennisParent\tIA1\t2\t3.50\tUS\tUSD\t08/01/2026",
        "APPLE\tTP_UNLOCK\tTennisParent\tIA1\t1\t3.50\tCA\tUSD\t08/02/2026",
        "APPLE\tTP_APP\tTennisParent\t1\t40\t0.00\tUS\tUSD\t08/01/2026",
    ].joined(separator: "\r\n")

    // MARK: - Parsing

    func testParsesTabSeparatedRows() {
        let rows = SalesReportParser.parseRows(report)

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0].sku, "TP_UNLOCK")
        XCTAssertEqual(rows[0].title, "TennisParent")
        XCTAssertEqual(rows[0].units, 2)
        XCTAssertEqual(rows[0].countryCode, "US")
    }

    func testEmptyReportParsesToNoRows() {
        XCTAssertTrue(SalesReportParser.parseRows("").isEmpty)
        XCTAssertTrue(SalesReportParser.parseRows("Provider\tSKU\tUnits").isEmpty)
    }

    /// Some report types append a free-text total line that does not match the
    /// column layout; it must not become a bogus row.
    func testMalformedTrailingLineIsSkipped() {
        let withTotal = report + "\r\nTotal_Rows: 3"

        XCTAssertEqual(SalesReportParser.parseRows(withTotal).count, 3)
    }

    // MARK: - In-app purchase classification

    func testProductTypeIdentifierClassifiesInAppPurchases() {
        let rows = SalesReportParser.parseRows(report)

        XCTAssertTrue(rows[0].isInAppPurchase, "IA1 is an in-app purchase")
        XCTAssertFalse(rows[2].isInAppPurchase, "1 is an app download")
    }

    func testSubscriptionProductTypesCountAsInAppPurchases() {
        let rows = SalesReportParser.parseRows([
            "SKU\tUnits\tProduct Type Identifier",
            "SUB\t1\tIAC",
            "SUBY\t1\tIAY",
        ].joined(separator: "\n"))

        XCTAssertTrue(rows.allSatisfy(\.isInAppPurchase))
    }

    // MARK: - Summary

    func testSummaryGroupsBySKUAcrossTerritories() {
        let summary = SalesReportParser.summarize(rows: SalesReportParser.parseRows(report))

        XCTAssertEqual(summary.lineItems.count, 2, "Two SKUs, not three rows")
        XCTAssertEqual(summary.totalInAppPurchaseUnits, 3, "2 US + 1 CA")
        XCTAssertEqual(summary.inAppPurchases.count, 1)
        XCTAssertEqual(summary.appDownloads.first?.units, 40)
    }

    /// "Developer Proceeds" is per unit, so a 2-unit row at 3.50 is 7.00.
    /// Summing the column alone would report 3.50 and undercount revenue.
    func testProceedsAreMultipliedByUnits() {
        let summary = SalesReportParser.summarize(rows: SalesReportParser.parseRows(report))

        XCTAssertEqual(summary.inAppPurchases.first?.proceeds, Decimal(string: "10.50"))
        XCTAssertEqual(summary.totalProceeds, Decimal(string: "10.50"))
    }

    func testAnAppAndItsIAPSharingASKUStemStaySeparate() {
        let rows = SalesReportParser.parseRows([
            "SKU\tUnits\tProduct Type Identifier\tDeveloper Proceeds",
            "SAME\t5\t1\t0.00",
            "SAME\t3\tIA1\t0.70",
        ].joined(separator: "\n"))

        let summary = SalesReportParser.summarize(rows: rows)

        XCTAssertEqual(summary.lineItems.count, 2)
        XCTAssertEqual(summary.totalInAppPurchaseUnits, 3)
    }

    func testMultipleCurrenciesAreTrackedNotSummedBlindly() {
        let rows = SalesReportParser.parseRows([
            "SKU\tUnits\tProduct Type Identifier\tDeveloper Proceeds\tCurrency of Proceeds",
            "A\t1\tIA1\t1.00\tUSD",
            "A\t1\tIA1\t1.00\tEUR",
        ].joined(separator: "\n"))

        let summary = SalesReportParser.summarize(rows: rows)

        XCTAssertEqual(summary.currencies, ["USD", "EUR"])
    }

    func testEmptySummaryReportsZeroRatherThanNil() {
        let summary = SalesReportParser.summarize(rows: [], periodsCovered: ["2026-07"], periodsWithNoData: ["2026-08"])

        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.totalInAppPurchaseUnits, 0)
        XCTAssertEqual(summary.periodsWithNoData, ["2026-08"])
    }
}
