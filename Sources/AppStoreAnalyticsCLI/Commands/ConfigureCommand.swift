import Foundation

struct ConfigureCommand {
    static func execute(
        issuerId: String?,
        keyId: String?,
        privateKeyPath: String?,
        appId: String?
    ) async throws {
        Logger.info("Configuring App Store Analytics CLI")

        // Prompt for missing values
        let finalIssuerId = issuerId ?? promptForValue(
            "Enter your Issuer ID",
            required: true
        )

        let finalKeyId = keyId ?? promptForValue(
            "Enter your API Key ID",
            required: true
        )

        let finalPrivateKeyPath = privateKeyPath ?? promptForValue(
            "Enter the path to your private key (.p8 file)",
            required: true
        )

        let finalAppId = appId ?? promptForValue(
            "Enter your default App ID",
            required: true
        )

        let defaultOutputDir = promptForValue(
            "Enter default output directory for reports",
            defaultValue: "./analytics-reports"
        )

        // Validate private key file exists
        let expandedKeyPath = UserInput.expandTildePath(finalPrivateKeyPath)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: expandedKeyPath) else {
            Logger.error("Private key file not found at: \(expandedKeyPath)")
            throw ConfigManagerError.privateKeyFileNotFound(path: expandedKeyPath)
        }

        // Check file permissions
        let attributes = try fileManager.attributesOfItem(atPath: expandedKeyPath)
        if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
            let permissions = posixPermissions.uint16Value & 0o777
            if permissions > 0o600 {
                Logger.error("Private key file has insecure permissions: \(String(format: "%o", permissions))")
                Logger.info("Run: chmod 600 \(expandedKeyPath)")

                if !UserInput.confirm(prompt: "Continue anyway?") {
                    Logger.info("Configuration cancelled")
                    return
                }
            }
        }

        // Create configuration
        let configuration = Configuration(
            issuerId: finalIssuerId,
            apiKeyId: finalKeyId,
            privateKeyPath: finalPrivateKeyPath,
            defaultAppId: finalAppId,
            defaultOutputDir: defaultOutputDir
        )

        // Test JWT generation
        Logger.info("Testing JWT token generation...")
        do {
            let jwtManager = JWTManager(
                issuerId: finalIssuerId,
                apiKeyId: finalKeyId,
                privateKeyPath: finalPrivateKeyPath
            )
            _ = try await jwtManager.getValidToken()
            Logger.ok("JWT token generated successfully")
        } catch {
            Logger.error("Failed to generate JWT token: \(error.localizedDescription)")
            throw error
        }

        // Test API connection
        Logger.info("Testing API connection...")
        do {
            let apiClient = try APIClient(configuration: configuration)
            try await apiClient.testConnection()
        } catch {
            Logger.error("Failed to connect to API: \(error.localizedDescription)")
            throw error
        }

        // Save configuration
        try ConfigManager.shared.saveConfiguration(configuration)

        Logger.success("Configuration complete!")
        Logger.info("You can now use the other commands to interact with App Store Analytics API")
    }

    private static func promptForValue(
        _ prompt: String,
        defaultValue: String? = nil,
        required: Bool = false
    ) -> String {
        var fullPrompt = prompt
        if let defaultValue = defaultValue {
            fullPrompt += " [\(defaultValue)]"
        }

        while true {
            if let value = UserInput.readLine(prompt: fullPrompt) {
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedValue.isEmpty {
                    return trimmedValue
                } else if let defaultValue = defaultValue {
                    return defaultValue
                }
            }

            if !required, let defaultValue = defaultValue {
                return defaultValue
            }

            if required {
                Logger.error("This field is required. Please enter a value.")
            }
        }
    }
}
