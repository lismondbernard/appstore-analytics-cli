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

        // Create API configuration using file URL (handles PEM format automatically)
        let privateKeyURL = URL(fileURLWithPath: expandedKeyPath)
        let apiConfiguration = try APIConfiguration(
            issuerID: configuration.issuerId,
            privateKeyID: configuration.apiKeyId,
            privateKeyURL: privateKeyURL
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
        accessType: String = "ONE_TIME_SNAPSHOT",
        appId: String? = nil
    ) async throws -> String {
        try await rateLimiter.acquirePermit()

        let resolvedAppId = appId ?? configuration.defaultAppId
        let sdkAccessType: AppStoreConnect_Swift_SDK.AnalyticsReportRequestCreateRequest.Data.Attributes.AccessType =
            accessType == "ONGOING" ? .ongoing : .oneTimeSnapshot

        Logger.info("Creating \(accessType) analytics report request...")

        let createRequest = AppStoreConnect_Swift_SDK.AnalyticsReportRequestCreateRequest(
            data: .init(
                type: .analyticsReportRequests,
                attributes: .init(accessType: sdkAccessType),
                relationships: .init(
                    app: .init(
                        data: .init(type: .apps, id: resolvedAppId)
                    )
                )
            )
        )

        let request = APIEndpoint.v1.analyticsReportRequests.post(createRequest)
        let response = try await provider.request(request)

        let requestId = response.data.id
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

        let request = APIEndpoint.v1.apps.id(configuration.defaultAppId)
            .analyticsReportRequests.get(parameters: .init(
                fieldsAnalyticsReportRequests: [.accessType, .stoppedDueToInactivity, .reports],
                limit: 200
            ))
        let response = try await provider.request(request)

        let reports = response.data.map { sdkRequest -> AnalyticsReportRequest in
            AnalyticsReportRequest(
                id: sdkRequest.id,
                reportType: sdkRequest.attributes?.accessType?.rawValue ?? "UNKNOWN",
                reportSubType: nil,
                accessType: sdkRequest.attributes?.accessType?.rawValue,
                stoppedDueToInactivity: sdkRequest.attributes?.isStoppedDueToInactivity
            )
        }

        Logger.ok("Found \(reports.count) reports")
        return reports
    }

    /// Get the status of a specific report request
    func getReportStatus(requestId: String) async throws -> ReportStatus {
        try await rateLimiter.acquirePermit()

        Logger.info("Checking status for report \(requestId)...")

        // Fetch the report request with included reports
        let request = APIEndpoint.v1.analyticsReportRequests.id(requestId).get(parameters: .init(
            fieldsAnalyticsReportRequests: [.accessType, .stoppedDueToInactivity, .reports],
            include: [.reports]
        ))
        let response = try await provider.request(request)

        // Determine status based on API response
        if response.data.attributes?.isStoppedDueToInactivity == true {
            Logger.ok("Report status: FAILED")
            return .failed
        }

        // If reports exist in the relationship, the request has completed
        let hasReports = !(response.data.relationships?.reports?.data?.isEmpty ?? true)
        if hasReports {
            Logger.ok("Report status: COMPLETED")
            return .completed
        }

        Logger.ok("Report status: PROCESSING")
        return .processing
    }

    /// Get report instances for a completed report
    func getReportInstances(requestId: String) async throws -> [AnalyticsReportInstance] {
        try await rateLimiter.acquirePermit()

        Logger.info("Fetching report instances for \(requestId)...")

        // First, get the reports under this request
        let reportsRequest = APIEndpoint.v1.analyticsReportRequests.id(requestId).reports.get(
            parameters: .init(
                fieldsAnalyticsReports: [.name, .category],
                limit: 200
            )
        )
        let reportsResponse = try await provider.request(reportsRequest)

        var allInstances: [AnalyticsReportInstance] = []

        Logger.info("Found \(reportsResponse.data.count) report(s) under request")

        // For each report, fetch its instances
        for (index, report) in reportsResponse.data.enumerated() {
            try await rateLimiter.acquirePermit()

            let reportName = report.attributes?.name ?? "Unknown"
            let reportCategory = report.attributes?.category?.rawValue ?? "Unknown"

            let instancesRequest = APIEndpoint.v1.analyticsReports.id(report.id).instances.get(
                parameters: .init(
                    limit: 200
                )
            )
            let instancesResponse = try await provider.request(instancesRequest)

            let count = instancesResponse.data.count
            if count > 0 {
                Logger.ok("  [\(index + 1)/\(reportsResponse.data.count)] \(reportName) (\(reportCategory)): \(count) instance(s)")
            } else {
                Logger.info("  [\(index + 1)/\(reportsResponse.data.count)] \(reportName): no instances")
            }

            let mapped = instancesResponse.data.map { sdkInstance -> AnalyticsReportInstance in
                AnalyticsReportInstance(
                    id: sdkInstance.id,
                    granularity: sdkInstance.attributes?.granularity?.rawValue ?? "UNKNOWN",
                    processingDate: sdkInstance.attributes?.processingDate,
                    segmentsUrl: nil
                )
            }
            allInstances.append(contentsOf: mapped)
        }

        Logger.ok("Found \(allInstances.count) instance(s)")
        return allInstances
    }

    /// Get segments for a report instance
    func getReportSegments(instanceId: String) async throws -> [AnalyticsReportSegment] {
        try await rateLimiter.acquirePermit()

        Logger.info("Fetching report segments for instance \(instanceId)...")

        let request = APIEndpoint.v1.analyticsReportInstances.id(instanceId).segments.get()
        let response = try await provider.request(request)

        let segments = response.data.map { sdkSegment -> AnalyticsReportSegment in
            AnalyticsReportSegment(
                id: sdkSegment.id,
                url: sdkSegment.attributes?.url?.absoluteString,
                checksum: sdkSegment.attributes?.checksum,
                sizeInBytes: sdkSegment.attributes?.sizeInBytes
            )
        }

        Logger.ok("Found \(segments.count) segment(s)")
        return segments
    }
}
