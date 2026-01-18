import Foundation

enum ConfigManagerError: LocalizedError {
    case configurationNotFound
    case invalidConfigurationFile
    case privateKeyFileNotFound(path: String)
    case insecurePrivateKeyPermissions(path: String)
    case saveFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .configurationNotFound:
            return "Configuration file not found. Run 'appstore-analytics configure' first."
        case .invalidConfigurationFile:
            return "Configuration file is invalid or corrupted."
        case .privateKeyFileNotFound(let path):
            return "Private key file not found at: \(path)"
        case .insecurePrivateKeyPermissions(let path):
            return "Private key file has insecure permissions at: \(path). Expected 600 or more restrictive."
        case .saveFailed(let reason):
            return "Failed to save configuration: \(reason)"
        }
    }
}

class ConfigManager {
    static let shared = ConfigManager()

    private let configFileName = ".appstore-analytics-config.json"
    private var configFilePath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/\(configFileName)"
    }

    private init() {}

    func loadConfiguration() throws -> Configuration {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: configFilePath) else {
            throw ConfigManagerError.configurationNotFound
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configFilePath))
            let decoder = JSONDecoder()
            let config = try decoder.decode(Configuration.self, from: data)

            // Validate private key file exists
            let expandedKeyPath = UserInput.expandTildePath(config.privateKeyPath)
            guard fileManager.fileExists(atPath: expandedKeyPath) else {
                throw ConfigManagerError.privateKeyFileNotFound(path: expandedKeyPath)
            }

            // Check private key file permissions (should be 600 or more restrictive)
            let attributes = try fileManager.attributesOfItem(atPath: expandedKeyPath)
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                let permissions = posixPermissions.uint16Value & 0o777
                // Warn if permissions are more permissive than 600
                if permissions > 0o600 {
                    Logger.error("Private key file has insecure permissions: \(String(format: "%o", permissions))")
                    Logger.info("Recommended: chmod 600 \(expandedKeyPath)")
                }
            }

            return config
        } catch let error as ConfigManagerError {
            throw error
        } catch {
            throw ConfigManagerError.invalidConfigurationFile
        }
    }

    func saveConfiguration(_ config: Configuration) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(config)
            try data.write(to: URL(fileURLWithPath: configFilePath), options: .atomic)

            // Set file permissions to 600 (read/write for owner only)
            let fileManager = FileManager.default
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: configFilePath
            )

            Logger.ok("Configuration saved to \(configFilePath)")
        } catch {
            throw ConfigManagerError.saveFailed(reason: error.localizedDescription)
        }
    }

    func configurationExists() -> Bool {
        return FileManager.default.fileExists(atPath: configFilePath)
    }
}
