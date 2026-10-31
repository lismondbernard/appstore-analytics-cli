import Foundation

struct ListReportsCommand {
    static func execute(
        format: String,
        appId: String?
    ) async throws {
        // Load configuration
        let config = try ConfigManager.shared.loadConfiguration()

        // Create API client
        let apiClient = try APIClient(configuration: config)

        // Resolve the target app the same way create-report does, and say which
        // one was used: silently falling back to the default is how this command
        // handed back another app's report requests (SSS-98).
        let resolvedAppId = appId ?? config.defaultAppId
        if format != "json" {
            Logger.info("App ID: \(resolvedAppId)\(appId != nil ? " (override)" : " (from config)")")
        }

        // Fetch reports
        let reports = try await apiClient.listReports(
            appId: resolvedAppId
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
