import Foundation

struct ListReportsCommand {
    static func execute(
        category: String?,
        status: String?,
        format: String
    ) async throws {
        // Load configuration
        let config = try ConfigManager.shared.loadConfiguration()

        // Validate category if provided
        if let category = category {
            guard let _ = ReportCategory(rawValue: category.lowercased()) else {
                Logger.error("Invalid category: \(category)")
                Logger.info("Valid categories:")
                for cat in ReportCategory.allCases {
                    Logger.info("  - \(cat.rawValue)")
                }
                throw NSError(domain: "ListReportsCommand", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid category"
                ])
            }
        }

        // Validate status if provided
        if let status = status {
            guard let _ = ReportStatus(rawValue: status.uppercased()) else {
                Logger.error("Invalid status: \(status)")
                Logger.info("Valid statuses: CREATED, PROCESSING, COMPLETED, FAILED")
                throw NSError(domain: "ListReportsCommand", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid status"
                ])
            }
        }

        // Create API client
        let apiClient = try APIClient(configuration: config)

        // Fetch reports
        let reports = try await apiClient.listReports(
            category: category,
            status: status
        )

        // Display reports
        if format == "json" {
            displayAsJSON(reports: reports)
        } else {
            displayAsTable(reports: reports)
        }
    }

    private static func displayAsTable(reports: [AnalyticsReportRequest]) {
        if reports.isEmpty {
            Logger.info("No reports found")
            return
        }

        Logger.info("\nAnalytics Reports:")
        Logger.info(String(repeating: "=", count: 80))

        for report in reports {
            Logger.info("ID: \(report.id)")
            Logger.info("  Type: \(report.reportType)")
            if let subType = report.reportSubType {
                Logger.info("  Sub-Type: \(subType)")
            }
            if let accessType = report.accessType {
                Logger.info("  Access: \(accessType)")
            }
            Logger.info(String(repeating: "-", count: 80))
        }

        Logger.info("\nTotal: \(reports.count) report(s)")
    }

    private static func displayAsJSON(reports: [AnalyticsReportRequest]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let jsonData = try encoder.encode(reports)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            Logger.error("Failed to encode reports as JSON: \(error.localizedDescription)")
        }
    }
}
