import Foundation

struct ConfigureCommand {
    static func execute(
        issuerId: String?,
        keyId: String?,
        privateKeyPath: String?,
        appId: String?,
        vendorNumbers: [String] = []
    ) async throws {
        let existing = try? ConfigManager.shared.loadConfiguration()

        // Passing any flag against an existing config means "update just these
        // fields": everything else keeps its stored value and nothing is
        // prompted for. Bare `configure` stays fully interactive, so first-time
        // setup and deliberate reconfiguration are unchanged.
        let isTargetedUpdate = existing != nil
            && (issuerId != nil || keyId != nil || privateKeyPath != nil || appId != nil || !vendorNumbers.isEmpty)

        Logger.info(isTargetedUpdate ? "Updating existing configuration" : "Configuring App Store Analytics CLI")

        func resolve(_ provided: String?, stored: String?, prompt: String) -> String {
            if let provided { return provided }
            if isTargetedUpdate, let stored { return stored }
            return promptForValue(prompt, required: true)
        }

        let finalIssuerId = resolve(issuerId, stored: existing?.issuerId, prompt: "Enter your Issuer ID")
        let finalKeyId = resolve(keyId, stored: existing?.apiKeyId, prompt: "Enter your API Key ID")
        let finalPrivateKeyPath = resolve(
            privateKeyPath,
            stored: existing?.privateKeyPath,
            prompt: "Enter the path to your private key (.p8 file)"
        )
        let finalAppId = resolve(appId, stored: existing?.defaultAppId, prompt: "Enter your default App ID")

        let defaultOutputDir: String
        if isTargetedUpdate, let stored = existing?.defaultOutputDir {
            defaultOutputDir = stored
        } else {
            defaultOutputDir = promptForValue(
                "Enter default output directory for reports",
                defaultValue: "./analytics-reports"
            )
        }

        // Optional: only the 'sales' command needs it, and it can't be looked
        // up via the API — it lives in App Store Connect under Payments and
        // Financial Reports. Keep whatever is already configured if skipped.
        // Comma-separated because a vendor number belongs to a legal entity:
        // re-incorporating issues a new one and history stays under the old.
        let existingVendors = existing?.vendorNumbers ?? []
        let finalVendorNumbers: [String]
        if !vendorNumbers.isEmpty {
            finalVendorNumbers = vendorNumbers
        } else if isTargetedUpdate {
            finalVendorNumbers = existingVendors
        } else {
            let entered = UserInput.readLine(
                prompt: "Enter vendor number(s) for Sales and Trends, comma-separated, oldest first (optional)"
                    + (existingVendors.isEmpty ? "" : " [\(existingVendors.joined(separator: ","))]")
            )?.trimmingCharacters(in: .whitespacesAndNewlines)

            let parsed = (entered ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            finalVendorNumbers = parsed.isEmpty ? existingVendors : parsed
        }

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
            vendorNumbers: finalVendorNumbers
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
