import Foundation

struct Configuration: Codable {
    let issuerId: String
    let apiKeyId: String
    let privateKeyPath: String
    let defaultAppId: String
    let defaultOutputDir: String
    /// Vendor numbers for Sales and Trends reports, oldest first.
    ///
    /// A list rather than a single value because a vendor number belongs to a
    /// legal entity, not to an app: re-incorporating (sole proprietor → LLC)
    /// issues a new one, and history stays under the old one forever. Querying
    /// only the current vendor silently loses every pre-conversion sale.
    ///
    /// Optional because the analytics commands don't need it, and because the
    /// App Store Connect API has no endpoint that exposes it — it has to be
    /// read out of App Store Connect → Payments and Financial Reports.
    let vendorNumbers: [String]

    enum CodingKeys: String, CodingKey {
        case issuerId = "issuer_id"
        case apiKeyId = "api_key_id"
        case privateKeyPath = "private_key_path"
        case defaultAppId = "default_app_id"
        case defaultOutputDir = "default_output_dir"
        case vendorNumbers = "vendor_numbers"
        case vendorNumber = "vendor_number"
    }

    init(
        issuerId: String,
        apiKeyId: String,
        privateKeyPath: String,
        defaultAppId: String,
        defaultOutputDir: String,
        vendorNumbers: [String] = []
    ) {
        self.issuerId = issuerId
        self.apiKeyId = apiKeyId
        self.privateKeyPath = privateKeyPath
        self.defaultAppId = defaultAppId
        self.defaultOutputDir = defaultOutputDir
        self.vendorNumbers = vendorNumbers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        issuerId = try container.decode(String.self, forKey: .issuerId)
        apiKeyId = try container.decode(String.self, forKey: .apiKeyId)
        privateKeyPath = try container.decode(String.self, forKey: .privateKeyPath)
        defaultAppId = try container.decode(String.self, forKey: .defaultAppId)
        defaultOutputDir = try container.decode(String.self, forKey: .defaultOutputDir)

        if let list = try container.decodeIfPresent([String].self, forKey: .vendorNumbers) {
            vendorNumbers = list
        } else if let single = try container.decodeIfPresent(String.self, forKey: .vendorNumber) {
            // Configs written before the entity change carried one value.
            vendorNumbers = [single]
        } else {
            vendorNumbers = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(issuerId, forKey: .issuerId)
        try container.encode(apiKeyId, forKey: .apiKeyId)
        try container.encode(privateKeyPath, forKey: .privateKeyPath)
        try container.encode(defaultAppId, forKey: .defaultAppId)
        try container.encode(defaultOutputDir, forKey: .defaultOutputDir)
        if !vendorNumbers.isEmpty {
            try container.encode(vendorNumbers, forKey: .vendorNumbers)
        }
    }
}
