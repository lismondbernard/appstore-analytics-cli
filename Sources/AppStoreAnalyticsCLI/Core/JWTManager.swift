import Foundation
import AppStoreConnect_Swift_SDK

enum JWTManagerError: LocalizedError {
    case invalidPrivateKey
    case tokenGenerationFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidPrivateKey:
            return "Invalid private key file. Ensure the .p8 file is valid."
        case .tokenGenerationFailed(let reason):
            return "Failed to generate JWT token: \(reason)"
        }
    }
}

actor JWTManager {
    private var currentToken: String?
    private var tokenExpiryDate: Date?
    private let tokenLifetime: TimeInterval = 18 * 60 // 18 minutes (buffer before 20 min expiry)

    private let issuerId: String
    private let apiKeyId: String
    private let privateKeyPath: String

    init(issuerId: String, apiKeyId: String, privateKeyPath: String) {
        self.issuerId = issuerId
        self.apiKeyId = apiKeyId
        self.privateKeyPath = privateKeyPath
    }

    func getValidToken() async throws -> String {
        // Check if current token is still valid
        if let token = currentToken,
           let expiry = tokenExpiryDate,
           expiry > Date() {
            return token
        }

        // Generate new token
        return try await generateNewToken()
    }

    private func generateNewToken() async throws -> String {
        // Expand tilde path
        let expandedPath = UserInput.expandTildePath(privateKeyPath)

        // Read private key from file
        guard let privateKeyData = try? String(contentsOfFile: expandedPath, encoding: .utf8) else {
            throw JWTManagerError.invalidPrivateKey
        }

        do {
            // Create JWT configuration to validate credentials
            // The SDK's JWT is handled internally by APIProvider
            _ = try APIConfiguration(
                issuerID: issuerId,
                privateKeyID: apiKeyId,
                privateKey: privateKeyData
            )

            // Generate placeholder token (actual JWT handled by APIProvider)
            let token = "jwt-token-placeholder"

            // Cache the token
            currentToken = token
            tokenExpiryDate = Date().addingTimeInterval(tokenLifetime)

            return token
        } catch {
            throw JWTManagerError.tokenGenerationFailed(reason: error.localizedDescription)
        }
    }

    func invalidateToken() {
        currentToken = nil
        tokenExpiryDate = nil
    }
}
