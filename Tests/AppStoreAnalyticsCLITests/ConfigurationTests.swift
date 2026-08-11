import XCTest
@testable import AppStoreAnalyticsCLI

final class ConfigurationTests: XCTestCase {

    private func decode(_ json: String) throws -> Configuration {
        try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    }

    private let required = """
    "issuer_id": "issuer",
    "api_key_id": "key",
    "private_key_path": "~/key.p8",
    "default_app_id": "123",
    "default_output_dir": "./out"
    """

    func testDecodesVendorNumberList() throws {
        let config = try decode("{\(required), \"vendor_numbers\": [\"80078236\", \"94679843\"]}")

        XCTAssertEqual(config.vendorNumbers, ["80078236", "94679843"])
    }

    /// Configs written before the entity change carried a single string.
    func testMigratesLegacySingleVendorNumber() throws {
        let config = try decode("{\(required), \"vendor_number\": \"80078236\"}")

        XCTAssertEqual(config.vendorNumbers, ["80078236"])
    }

    /// Configs written before sales support existed have neither key.
    func testDecodesWithNoVendorNumberAtAll() throws {
        let config = try decode("{\(required)}")

        XCTAssertTrue(config.vendorNumbers.isEmpty)
        XCTAssertEqual(config.issuerId, "issuer")
    }

    func testVendorNumbersRoundTripAsAList() throws {
        let original = Configuration(
            issuerId: "issuer",
            apiKeyId: "key",
            privateKeyPath: "~/key.p8",
            defaultAppId: "123",
            defaultOutputDir: "./out",
            vendorNumbers: ["80078236", "94679843"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Configuration.self, from: data)

        XCTAssertEqual(decoded.vendorNumbers, original.vendorNumbers)
        // Order matters: it is the chronological order of the entities.
        XCTAssertEqual(decoded.vendorNumbers.first, "80078236")
    }

    func testEmptyVendorListIsOmittedFromEncodedConfig() throws {
        let config = Configuration(
            issuerId: "issuer",
            apiKeyId: "key",
            privateKeyPath: "~/key.p8",
            defaultAppId: "123",
            defaultOutputDir: "./out"
        )

        let data = try JSONEncoder().encode(config)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(json.contains("vendor_numbers"))
    }
}
