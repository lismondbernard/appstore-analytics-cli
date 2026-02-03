import Foundation

struct AppStoreAnalyticsCLI {
    static let version = "1.0.0"

    func run() async {
        let arguments = Array(CommandLine.arguments.dropFirst())

        guard let command = Command.parse(arguments: arguments) else {
            Logger.error("Invalid command or missing required arguments")
            printUsage()
            exit(1)
        }

        do {
            switch command {
            case .configure(let issuerId, let keyId, let privateKeyPath, let appId):
                try await ConfigureCommand.execute(
                    issuerId: issuerId,
                    keyId: keyId,
                    privateKeyPath: privateKeyPath,
                    appId: appId
                )

            case .createReport(let reportType, let startDate, let endDate, let granularity, let wait, let download, let accessType):
                try await CreateReportCommand.execute(
                    reportType: reportType,
                    startDate: startDate,
                    endDate: endDate,
                    granularity: granularity,
                    wait: wait,
                    download: download,
                    accessType: accessType
                )

            case .listReports(let category, let status, let format):
                try await ListReportsCommand.execute(
                    category: category,
                    status: status,
                    format: format
                )

            case .download(let reportRequestId, let outputDir, let merge, let overwrite):
                try await DownloadCommand.execute(
                    reportRequestId: reportRequestId,
                    outputDir: outputDir,
                    merge: merge,
                    overwrite: overwrite
                )

            case .status(let reportRequestId, let watch, let interval):
                try await StatusCommand.execute(
                    reportRequestId: reportRequestId,
                    watch: watch,
                    interval: interval
                )

            case .deleteReport(let reportRequestId):
                try await DeleteReportCommand.execute(
                    reportRequestId: reportRequestId
                )

            case .help:
                printUsage()

            case .version:
                print("App Store Analytics CLI v\(AppStoreAnalyticsCLI.version)")
            }
        } catch {
            Logger.error(error.localizedDescription)
            exit(1)
        }
    }

    func printUsage() {
        print("""
        App Store Analytics CLI - Generate reports from App Store Analytics API

        USAGE:
            appstore-analytics <command> [options]

        COMMANDS:
            configure              Set up API credentials
            create-report          Create a new analytics report request
            list-reports           List available reports
            download               Download report CSV files
            status                 Check report status
            delete-report          Delete an analytics report request
            help                   Show this help message
            version                Show version information

        CONFIGURE:
            appstore-analytics configure \\
                --issuer-id <ISSUER_ID> \\
                --key-id <KEY_ID> \\
                --private-key-path <PATH_TO_P8> \\
                --app-id <APP_ID>

        CREATE REPORT:
            appstore-analytics create-report \\
                --report-type <REPORT_TYPE> \\
                --start-date <YYYY-MM-DD> \\
                --end-date <YYYY-MM-DD> \\
                [--granularity DAILY|WEEKLY|MONTHLY] \\
                [--wait] \\
                [--download]

        LIST REPORTS:
            appstore-analytics list-reports \\
                [--category discovery|commerce|usage|performance] \\
                [--status created|processing|completed|failed] \\
                [--format table|json]

        DOWNLOAD:
            appstore-analytics download <REPORT_REQUEST_ID> \\
                [--output-dir <DIR>] \\
                [--merge] \\
                [--overwrite]

        STATUS:
            appstore-analytics status <REPORT_REQUEST_ID> \\
                [--watch] \\
                [--interval <SECONDS>]

        DELETE REPORT:
            appstore-analytics delete-report <REPORT_REQUEST_ID>

        EXAMPLES:
            # Initial setup
            appstore-analytics configure

            # Create a report
            appstore-analytics create-report \\
                --report-type APP_STORE_PRODUCT_PAGE_VIEWS \\
                --start-date 2026-01-01 \\
                --end-date 2026-01-14 \\
                --granularity DAILY

            # List all reports
            appstore-analytics list-reports

            # Download a report
            appstore-analytics download abc-123-def

        For more information, visit: https://developer.apple.com/documentation/appstoreconnectapi
        """)
    }
}

// Run the CLI
let cli = AppStoreAnalyticsCLI()
await cli.run()
