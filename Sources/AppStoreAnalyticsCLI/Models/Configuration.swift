import Foundation

struct Configuration: Codable {
    let issuerId: String
    let apiKeyId: String
    let privateKeyPath: String
    let defaultAppId: String
    let defaultOutputDir: String
    /// Vendor number for Sales and Trends reports. Optional because the
    /// analytics commands don't need it, and because the App Store Connect
    /// API has no endpoint that exposes it — it has to be read out of
    /// App Store Connect → Payments and Financial Reports.
    let vendorNumber: String?

    enum CodingKeys: String, CodingKey {
        case issuerId = "issuer_id"
        case apiKeyId = "api_key_id"
        case privateKeyPath = "private_key_path"
        case defaultAppId = "default_app_id"
        case defaultOutputDir = "default_output_dir"
        case vendorNumber = "vendor_number"
    }

    init(
        issuerId: String,
        apiKeyId: String,
        privateKeyPath: String,
        defaultAppId: String,
        defaultOutputDir: String,
        vendorNumber: String? = nil
    ) {
        self.issuerId = issuerId
        self.apiKeyId = apiKeyId
        self.privateKeyPath = privateKeyPath
        self.defaultAppId = defaultAppId
        self.defaultOutputDir = defaultOutputDir
        self.vendorNumber = vendorNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        issuerId = try container.decode(String.self, forKey: .issuerId)
        apiKeyId = try container.decode(String.self, forKey: .apiKeyId)
        privateKeyPath = try container.decode(String.self, forKey: .privateKeyPath)
        defaultAppId = try container.decode(String.self, forKey: .defaultAppId)
        defaultOutputDir = try container.decode(String.self, forKey: .defaultOutputDir)
        // Absent in configs written before sales support existed.
        vendorNumber = try container.decodeIfPresent(String.self, forKey: .vendorNumber)
    }
}
