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

        // Optional: only the 'sales' command needs it, and it can't be looked
        // up via the API — it lives in App Store Connect under Payments and
        // Financial Reports. Keep whatever is already configured if skipped.
        let existing = try? ConfigManager.shared.loadConfiguration()
        let enteredVendorNumber = UserInput.readLine(
            prompt: "Enter your vendor number for Sales and Trends (optional)\(existing?.vendorNumber.map { " [\($0)]" } ?? "")"
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalVendorNumber = (enteredVendorNumber?.isEmpty == false ? enteredVendorNumber : nil)
            ?? existing?.vendorNumber

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
            defaultOutputDir: defaultOutputDir,
            vendorNumber: finalVendorNumber
        )

        // Validate private key can be read
        Logger.info("Validating private key file...")
        guard let _ = try? String(contentsOfFile: expandedKeyPath, encoding: .utf8) else {
            Logger.error("Failed to read private key file")
            Logger.info("Please ensure the file is a valid .p8 private key")
            throw ConfigManagerError.privateKeyFileNotFound(path: expandedKeyPath)
        }
        Logger.ok("Private key file validated")

        // Save configuration
        try ConfigManager.shared.saveConfiguration(configuration)

        Logger.success("Configuration saved successfully!")
        Logger.info("Your API credentials will be validated when you run your first command")
        Logger.info("Try: appstore-analytics create-report --help")
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
