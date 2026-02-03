import Foundation

struct CreateReportCommand {
    static func execute(
        reportType: String,
        startDate: String,
        endDate: String,
        granularity: String,
        wait: Bool,
        download: Bool,
        accessType: String = "ONE_TIME_SNAPSHOT"
    ) async throws {
        // Load configuration
        let config = try ConfigManager.shared.loadConfiguration()

        let isOngoing = accessType == "ONGOING"

        // Validate access type
        guard accessType == "ONE_TIME_SNAPSHOT" || accessType == "ONGOING" else {
            Logger.error("Invalid access type: \(accessType)")
            Logger.info("Valid options: ONE_TIME_SNAPSHOT, ONGOING")
            throw NSError(domain: "CreateReportCommand", code: 9, userInfo: [
                NSLocalizedDescriptionKey: "Invalid access type"
            ])
        }

        // Only validate report type, dates, and granularity for ONE_TIME_SNAPSHOT
        if !isOngoing {
            // Validate report type
            guard let _ = ReportType(rawValue: reportType) else {
                Logger.error("Invalid report type: \(reportType)")
                Logger.info("Available report types:")
                for type in ReportType.allCases.prefix(10) {
                    Logger.info("  - \(type.rawValue): \(type.displayName)")
                }
                Logger.info("  ... and \(ReportType.allCases.count - 10) more")
                throw NSError(domain: "CreateReportCommand", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid report type"
                ])
            }

            // Validate dates
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

            guard let start = dateFormatter.date(from: startDate) else {
                Logger.error("Invalid start date format: \(startDate)")
                Logger.info("Expected format: YYYY-MM-DD")
                throw NSError(domain: "CreateReportCommand", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid start date format"
                ])
            }

            guard let end = dateFormatter.date(from: endDate) else {
                Logger.error("Invalid end date format: \(endDate)")
                Logger.info("Expected format: YYYY-MM-DD")
                throw NSError(domain: "CreateReportCommand", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid end date format"
                ])
            }

            // Validate date range (max 365 days)
            let daysDifference = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            if daysDifference > 365 {
                Logger.error("Date range exceeds maximum of 365 days")
                throw NSError(domain: "CreateReportCommand", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Date range too large"
                ])
            }

            if daysDifference < 0 {
                Logger.error("End date must be after start date")
                throw NSError(domain: "CreateReportCommand", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid date range"
                ])
            }

            // Validate granularity
            guard let _ = Granularity(rawValue: granularity) else {
                Logger.error("Invalid granularity: \(granularity)")
                Logger.info("Valid options: DAILY, WEEKLY, MONTHLY")
                throw NSError(domain: "CreateReportCommand", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid granularity"
                ])
            }
        }

        // Create API client
        let apiClient = try APIClient(configuration: config)

        // Create report request
        let requestId = try await apiClient.createReportRequest(
            accessType: accessType,
            appId: config.defaultAppId
        )

        Logger.success("Report request created successfully")
        Logger.info("Report Request ID: \(requestId)")
        Logger.info("Access Type: \(accessType)")
        if !isOngoing {
            Logger.info("Requested Report Type: \(reportType)")
            Logger.info("Date Range: \(startDate) to \(endDate)")
            Logger.info("Granularity: \(granularity)")
            Logger.info("Note: Apple generates all report types per request. Use --report-type with 'status' or 'download' to filter to \(reportType).")
        }

        // Wait for completion if requested
        if wait {
            Logger.info("Waiting for report to complete...")
            try await waitForCompletion(apiClient: apiClient, requestId: requestId)

            // Download if requested
            if download {
                Logger.info("\nAuto-downloading report...")
                try await DownloadCommand.execute(
                    reportRequestId: requestId,
                    outputDir: nil,
                    merge: true,
                    overwrite: false
                )
            }
        } else {
            Logger.info("Use 'appstore-analytics status \(requestId)' to check progress")
        }
    }

    private static func waitForCompletion(apiClient: APIClient, requestId: String) async throws {
        var attempts = 0
        let maxAttempts = 120  // 1 hour with 30s intervals
        let pollInterval: UInt64 = 30_000_000_000  // 30 seconds

        while attempts < maxAttempts {
            let result = try await apiClient.getReportStatus(requestId: requestId)

            switch result.status {
            case .completed:
                Logger.success("Report completed!")
                return
            case .failed:
                Logger.error("Report generation failed")
                throw NSError(domain: "CreateReportCommand", code: 7, userInfo: [
                    NSLocalizedDescriptionKey: "Report generation failed"
                ])
            case .processing, .created:
                Logger.info("Status: \(result.status.rawValue) (attempt \(attempts + 1)/\(maxAttempts))")
                try await Task.sleep(nanoseconds: pollInterval)
            }

            attempts += 1
        }

        Logger.error("Timeout waiting for report completion")
        throw NSError(domain: "CreateReportCommand", code: 8, userInfo: [
            NSLocalizedDescriptionKey: "Timeout waiting for report"
        ])
    }
}
