import XCTest
@testable import AppStoreAnalyticsCLI

final class DownloadManifestTests: XCTestCase {

    private func makeManifest() -> DownloadManifest {
        DownloadManifest(
            reportRequestId: "18beb008-3a95-403c-a9e9-a5639d07372a",
            instances: [
                .init(instanceId: "abc",
                      directory: "instance-abc",
                      reportName: "App Downloads Standard",
                      reportCategory: "COMMERCE",
                      granularity: "DAILY",
                      processingDate: "2026-08-21"),
                .init(instanceId: "def",
                      directory: "instance-def",
                      reportName: nil,
                      reportCategory: nil,
                      granularity: "UNKNOWN",
                      processingDate: nil)
            ]
        )
    }

    private func encoded(_ manifest: DownloadManifest) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// The Python summarizer reads these keys by name, so they are part of the
    /// contract rather than an encoding detail.
    func testEncodesSnakeCaseKeysTheSummarizerReads() throws {
        let json = try encoded(makeManifest())
        XCTAssertEqual(json["report_request_id"] as? String, "18beb008-3a95-403c-a9e9-a5639d07372a")

        let instances = try XCTUnwrap(json["instances"] as? [[String: Any]])
        XCTAssertEqual(instances.count, 2)
        XCTAssertEqual(instances[0]["instance_id"] as? String, "abc")
        XCTAssertEqual(instances[0]["directory"] as? String, "instance-abc")
        XCTAssertEqual(instances[0]["granularity"] as? String, "DAILY")
        XCTAssertEqual(instances[0]["report_name"] as? String, "App Downloads Standard")
        XCTAssertEqual(instances[0]["report_category"] as? String, "COMMERCE")
        XCTAssertEqual(instances[0]["processing_date"] as? String, "2026-08-21")
    }

    /// Granularity is non-optional precisely so a reader never has to guess:
    /// the API's "UNKNOWN" must survive as a value rather than a missing key.
    func testUnknownGranularityIsWrittenRatherThanOmitted() throws {
        let json = try encoded(makeManifest())
        let instances = try XCTUnwrap(json["instances"] as? [[String: Any]])
        XCTAssertEqual(instances[1]["granularity"] as? String, "UNKNOWN")
        XCTAssertNotEqual(instances[1]["granularity"] as? String, "DAILY")
    }

    func testRoundTrips() throws {
        let data = try JSONEncoder().encode(makeManifest())
        let decoded = try JSONDecoder().decode(DownloadManifest.self, from: data)
        XCTAssertEqual(decoded.reportRequestId, "18beb008-3a95-403c-a9e9-a5639d07372a")
        XCTAssertEqual(decoded.instances.map(\.instanceId), ["abc", "def"])
        XCTAssertEqual(decoded.instances.map(\.granularity), ["DAILY", "UNKNOWN"])
        XCTAssertNil(decoded.instances[1].reportName)
    }

    /// A manifest entry's granularity is what `Granularity.matches` is fed, so
    /// the two have to agree on spelling.
    func testGranularityStringsMatchTheFilterEnum() throws {
        let decoded = try JSONDecoder().decode(
            DownloadManifest.self,
            from: try JSONEncoder().encode(makeManifest())
        )
        XCTAssertTrue(Granularity.daily.matches(instanceGranularity: decoded.instances[0].granularity))
        XCTAssertFalse(Granularity.daily.matches(instanceGranularity: decoded.instances[1].granularity))
    }
}
