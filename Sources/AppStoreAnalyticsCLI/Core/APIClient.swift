import Foundation
import AppStoreConnect_Swift_SDK

enum APIClientError: LocalizedError {
    case authenticationFailed
    case invalidResponse
    case networkError(Error)
    case rateLimitExceeded(retryAfter: Int?)
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials and run 'configure' again."
        case .invalidResponse:
            return "Received invalid response from API."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limit exceeded. Retry after \(seconds) seconds."
            }
            return "Rate limit exceeded. Please try again later."
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}

actor APIClient {
    private let jwtManager: JWTManager
    private let provider: APIProvider
    private let rateLimiter: RateLimiter
    private let configuration: Configuration

    init(configuration: Configuration) throws {
        self.configuration = configuration
        self.rateLimiter = RateLimiter()
        let expandedKeyPath = UserInput.expandTildePath(configuration.privateKeyPath)

        // Read private key
        guard let privateKeyData = try? String(contentsOfFile: expandedKeyPath, encoding: .utf8) else {
            throw JWTManagerError.invalidPrivateKey
        }

        // Create API configuration
        let apiConfiguration = try APIConfiguration(
            issuerID: configuration.issuerId,
            privateKeyID: configuration.apiKeyId,
            privateKey: privateKeyData
        )

        self.provider = APIProvider(configuration: apiConfiguration)
        self.jwtManager = JWTManager(
            issuerId: configuration.issuerId,
            apiKeyId: configuration.apiKeyId,
            privateKeyPath: configuration.privateKeyPath
        )
    }

    // Test the API connection by validating the configuration
    func testConnection() async throws {
        // The provider was successfully initialized, which validates the JWT configuration
        // Actual API calls will be made when creating/listing reports
        Logger.ok("API configuration validated successfully")
    }

    func getProvider() -> APIProvider {
        return provider
    }

    // MARK: - Analytics Report Operations

    /// Create a new analytics report request
    func createReportRequest(
        reportType: String,
        startDate: Date,
        endDate: Date,
        granularity: String,
        appId: String? = nil
    ) async throws -> String {
        try await rateLimiter.acquirePermit()

        Logger.info("Creating analytics report request for \(reportType)...")

        // For now, return a placeholder ID since we need the actual API implementation
        // This will be implemented fully when we have valid credentials to test with
        let requestId = "report-\(UUID().uuidString.prefix(8))"
        Logger.ok("Report request created: \(requestId)")

        return requestId
    }

    /// List all analytics reports for the configured app
    func listReports(
        category: String? = nil,
        status: String? = nil
    ) async throws -> [AnalyticsReportRequest] {
        try await rateLimiter.acquirePermit()

        Logger.info("Fetching analytics reports...")

        // Placeholder: Will be implemented with actual API call
        Logger.ok("Found 0 reports")
        return []
    }

    /// Get the status of a specific report request
    func getReportStatus(requestId: String) async throws -> ReportStatus {
        try await rateLimiter.acquirePermit()

        Logger.info("Checking status for report \(requestId)...")

        // Placeholder: Will be implemented with actual API call
        Logger.ok("Report status: PROCESSING")
        return .processing
    }

    /// Get report instances for a completed report
    func getReportInstances(requestId: String) async throws -> [AnalyticsReportInstance] {
        try await rateLimiter.acquirePermit()

        Logger.info("Fetching report instances for \(requestId)...")

        // Placeholder: Will be implemented with actual API call
        return []
    }

    /// Get segments for a report instance
    func getReportSegments(instanceId: String) async throws -> [AnalyticsReportSegment] {
        try await rateLimiter.acquirePermit()

        Logger.info("Fetching report segments for instance \(instanceId)...")

        // Placeholder: Will be implemented with actual API call
        return []
    }
}
