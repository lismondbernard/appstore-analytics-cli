import Foundation

struct StatusCommand {
    static func execute(
        reportRequestId: String,
        watch: Bool,
        interval: Int,
        reportType: String? = nil
    ) async throws {
        // Load configuration
        let config = try ConfigManager.shared.loadConfiguration()

        // Create API client
        let apiClient = try APIClient(configuration: config)

        if watch {
            try await watchStatus(
                apiClient: apiClient,
                requestId: reportRequestId,
                interval: interval
            )
        } else {
            try await checkOnce(
                apiClient: apiClient,
                requestId: reportRequestId,
                reportType: reportType
            )
        }
    }

    private static func checkOnce(
        apiClient: APIClient,
        requestId: String,
        reportType: String? = nil
    ) async throws {
        Logger.info("Checking status for report: \(requestId)")

        let result = try await apiClient.getReportStatus(requestId: requestId)

        if let accessType = result.accessType {
            Logger.info("Access Type: \(accessType)")
        }

        if !result.reports.isEmpty {
            let filteredReports: [AnalyticsReport]
            if let reportType = reportType,
               let knownType = ReportType(rawValue: reportType) {
                let targetName = knownType.displayName.lowercased()
                filteredReports = result.reports.filter {
                    $0.name.lowercased() == targetName
                }
                if filteredReports.isEmpty {
                    Logger.info("No reports matching type '\(reportType)' found in this request")
                    Logger.info("Total report types in request: \(result.reports.count)")
                } else {
                    Logger.info("Matching Reports (filtered by \(reportType)):")
                    for report in filteredReports {
                        let category = report.category.map { " (\($0))" } ?? ""
                        Logger.info("  - \(report.name)\(category)")
                    }
                    Logger.info("(\(result.reports.count) total report types in request, showing \(filteredReports.count) matching)")
                }
            } else {
                Logger.info("Report Types (\(result.reports.count) total):")
                for report in result.reports {
                    let category = report.category.map { " (\($0))" } ?? ""
                    Logger.info("  - \(report.name)\(category)")
                }
                Logger.info("Tip: Use --report-type <TYPE> to filter this list")
            }
        }

        Logger.info("Report Status: \(result.status.rawValue)")

        switch result.status {
        case .created:
            Logger.info("Report request has been created and is queued for processing")
        case .processing:
            Logger.info("Report is currently being processed")
            Logger.info("Use --watch flag to monitor progress")
        case .completed:
            Logger.success("Report is ready for download")
            Logger.info("Use 'appstore-analytics download \(requestId)' to download")
        case .failed:
            Logger.error("Report generation failed")
            Logger.info("Please check your report parameters and try again")
        }
    }

    private static func watchStatus(
        apiClient: APIClient,
        requestId: String,
        interval: Int
    ) async throws {
        Logger.info("Monitoring report: \(requestId)")
        Logger.info("Checking every \(interval) seconds (Press Ctrl+C to stop)")
        Logger.info(String(repeating: "=", count: 60))

        var attempt = 0
        let pollInterval = UInt64(interval) * 1_000_000_000  // Convert to nanoseconds

        while true {
            attempt += 1
            let timestamp = DateFormatter.localizedString(
                from: Date(),
                dateStyle: .none,
                timeStyle: .medium
            )

            let result = try await apiClient.getReportStatus(requestId: requestId)

            Logger.info("[\(timestamp)] Attempt \(attempt): \(result.status.rawValue)")

            switch result.status {
            case .completed:
                Logger.success("Report completed!")
                Logger.info("Use 'appstore-analytics download \(requestId)' to download")
                return
            case .failed:
                Logger.error("Report generation failed")
                throw NSError(domain: "StatusCommand", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Report generation failed"
                ])
            case .created, .processing:
                // Continue watching
                try await Task.sleep(nanoseconds: pollInterval)
            }
        }
    }
}
