import Foundation

struct Configuration: Codable {
    let issuerId: String
    let apiKeyId: String
    let privateKeyPath: String
    let defaultAppId: String
    let defaultOutputDir: String

    enum CodingKeys: String, CodingKey {
        case issuerId = "issuer_id"
        case apiKeyId = "api_key_id"
        case privateKeyPath = "private_key_path"
        case defaultAppId = "default_app_id"
        case defaultOutputDir = "default_output_dir"
    }
}
