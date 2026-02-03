import Foundation

struct DeleteReportCommand {
    static func execute(reportRequestId: String) async throws {
        let config = try ConfigManager.shared.loadConfiguration()
        let apiClient = try APIClient(configuration: config)

        Logger.info("Deleting report request: \(reportRequestId)")

        try await apiClient.deleteReportRequest(requestId: reportRequestId)

        Logger.success("Report request \(reportRequestId) deleted successfully")
    }
}
