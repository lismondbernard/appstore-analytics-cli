import XCTest
@testable import AppStoreAnalyticsCLI

/// Argument-parsing contracts.
///
/// These exist because of SSS-98: `list-reports --app-id <id>` was accepted by
/// the CLI, silently discarded by the parser, and answered with the *default*
/// app's report requests. Nothing failed, so the wrong app's data looked right.
final class CommandParsingTests: XCTestCase {

    // MARK: - list-reports --app-id (the regression)

    func testListReportsCarriesAppIdOverride() {
        guard case .listReports(_, _, _, let appId)? =
                Command.parse(arguments: ["list-reports", "--app-id", "598715944"]) else {
            return XCTFail("expected a listReports command")
        }
        XCTAssertEqual(appId, "598715944", "--app-id must reach the command, not be swallowed")
    }

    func testListReportsWithoutAppIdDefersToConfig() {
        guard case .listReports(_, _, _, let appId)? =
                Command.parse(arguments: ["list-reports"]) else {
            return XCTFail("expected a listReports command")
        }
        XCTAssertNil(appId, "no override means fall back to the configured default app")
    }

    func testListReportsAppIdCoexistsWithOtherFlags() {
        guard case .listReports(let category, let status, let format, let appId)? =
                Command.parse(arguments: [
                    "list-reports", "--category", "discovery",
                    "--status", "completed", "--format", "json",
                    "--app-id", "598715944",
                ]) else {
            return XCTFail("expected a listReports command")
        }
        XCTAssertEqual(category, "discovery")
        XCTAssertEqual(status, "completed")
        XCTAssertEqual(format, "json")
        XCTAssertEqual(appId, "598715944")
    }

    func testCreateReportStillCarriesAppIdOverride() {
        guard case .createReport(_, _, _, _, _, _, _, let appId)? =
                Command.parse(arguments: ["create-report", "--ongoing", "--app-id", "598715944"]) else {
            return XCTFail("expected a createReport command")
        }
        XCTAssertEqual(appId, "598715944")
    }

    // MARK: - Unknown options fail loudly

    func testUnknownOptionIsRejectedRatherThanIgnored() {
        XCTAssertNil(Command.parse(arguments: ["list-reports", "--app-di", "598715944"]),
                     "a typo'd flag must be an error, not a silent no-op")
        XCTAssertNil(Command.parse(arguments: ["create-report", "--ongoing", "--nope"]))
        XCTAssertNil(Command.parse(arguments: ["sales", "--not-a-flag"]))
        XCTAssertNil(Command.parse(arguments: ["configure", "--bogus", "x"]))
        XCTAssertNil(Command.parse(arguments: ["list-report-types", "--bogus"]))
        XCTAssertNil(Command.parse(arguments: ["download", "abc-123", "--bogus"]))
        XCTAssertNil(Command.parse(arguments: ["status", "abc-123", "--bogus"]))
        XCTAssertNil(Command.parse(arguments: ["delete-report", "abc-123", "--bogus"]))
    }

    // MARK: - Positional arguments still pass through

    func testPositionalArgumentsAreNotMistakenForOptions() {
        guard case .download(let id, _, _, _, _, _)? =
                Command.parse(arguments: ["download", "abc-123-def", "--merge"]) else {
            return XCTFail("expected a download command")
        }
        XCTAssertEqual(id, "abc-123-def")

        guard case .status(let statusId, let watch, _, _)? =
                Command.parse(arguments: ["status", "abc-123-def", "--watch"]) else {
            return XCTFail("expected a status command")
        }
        XCTAssertEqual(statusId, "abc-123-def")
        XCTAssertTrue(watch)
    }

    func testKnownFlagsAcrossCommandsStillParse() {
        XCTAssertNotNil(Command.parse(arguments: ["sales", "--vendor-number", "123,456", "--last", "3"]))
        XCTAssertNotNil(Command.parse(arguments: ["configure", "--app-id", "598715944"]))
        XCTAssertNotNil(Command.parse(arguments: ["list-report-types", "--category", "discovery"]))
    }
}
