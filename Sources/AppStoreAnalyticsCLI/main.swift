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
            case .configure(let issuerId, let keyId, let privateKeyPath, let appId, let vendorNumbers):
                try await ConfigureCommand.execute(
                    issuerId: issuerId,
                    keyId: keyId,
                    privateKeyPath: privateKeyPath,
                    appId: appId,
                    vendorNumbers: vendorNumbers
                )

            case .createReport(let reportType, let startDate, let endDate, let granularity, let wait, let download, let accessType, let appId):
                try await CreateReportCommand.execute(
                    reportType: reportType,
                    startDate: startDate,
                    endDate: endDate,
                    granularity: granularity,
                    wait: wait,
                    download: download,
                    accessType: accessType,
                    appId: appId
                )

            case .listReports(let category, let status, let format):
                try await ListReportsCommand.execute(
                    category: category,
                    status: status,
                    format: format
                )

            case .download(let reportRequestId, let outputDir, let merge, let overwrite, let reportType, let granularity):
                try await DownloadCommand.execute(
                    reportRequestId: reportRequestId,
                    outputDir: outputDir,
                    merge: merge,
                    overwrite: overwrite,
                    reportType: reportType,
                    granularity: granularity
                )

            case .status(let reportRequestId, let watch, let interval, let reportType):
                try await StatusCommand.execute(
                    reportRequestId: reportRequestId,
                    watch: watch,
                    interval: interval,
                    reportType: reportType
                )

            case .deleteReport(let reportRequestId):
                try await DeleteReportCommand.execute(
                    reportRequestId: reportRequestId
                )

            case .listReportTypes(let category):
                ListReportTypesCommand.execute(category: category)

            case .sales(let vendorNumbers, let frequency, let reportDate, let last, let reportType, let detailed, let format, let outputPath):
                try await SalesCommand.execute(
                    vendorNumbers: vendorNumbers,
                    frequency: frequency,
                    reportDate: reportDate,
                    last: last,
                    reportType: reportType,
                    detailed: detailed,
                    format: format,
                    outputPath: outputPath
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
            sales                  Show actual units and proceeds (Sales and Trends)
            list-report-types      List available report types
            help                   Show this help message
            version                Show version information

        CONFIGURE:
            appstore-analytics configure \\
                --issuer-id <ISSUER_ID> \\
                --key-id <KEY_ID> \\
                --private-key-path <PATH_TO_P8> \\
                --app-id <APP_ID> \\
                [--vendor-number <NUMBER>[,<NUMBER>...]]

            Run bare for an interactive setup. Passing any flag against an
            existing config updates only those fields and leaves the rest alone,
            so e.g. 'configure --vendor-number 123,456' won't re-prompt for
            credentials.

        CREATE REPORT:
            appstore-analytics create-report \\
                --report-type <REPORT_TYPE> \\
                --start-date <YYYY-MM-DD> \\
                --end-date <YYYY-MM-DD> \\
                [--granularity DAILY|WEEKLY|MONTHLY] \\
                [--access-type ONE_TIME_SNAPSHOT|ONGOING] \\
                [--app-id <APP_ID>] \\
                [--wait] \\
                [--download]

        LIST REPORTS:
            appstore-analytics list-reports \\
                [--category discovery|commerce|usage|performance] \\
                [--status created|processing|completed|failed] \\
                [--format table|json]

        DOWNLOAD:
            appstore-analytics download <REPORT_REQUEST_ID> \\
                [--report-type <REPORT_NAME>] \\
                [--granularity DAILY|WEEKLY|MONTHLY] \\
                [--output-dir <DIR>] \\
                [--merge] \\
                [--overwrite]

            --report-type matches Apple's own report names, case-insensitively
            and on any substring: 'App Downloads Standard' selects one report,
            'discovery' selects both the Standard and Detailed cuts. Run
            'status <ID>' to list the names available under a request. These
            names are unrelated to the REPORT TYPES listed further down, which
            name the older catalogue used by create-report. A name that matches
            nothing is an error, not an unfiltered download.

            Downloading without a filter fetches every instance, and those
            overlap: Apple emits DAILY, WEEKLY and MONTHLY instances of the
            same report plus rolling restatements of recent days, in both a
            Standard and a Detailed cut. Summing the CSVs triple-counts — see
            scripts/summarize-refresh.py.

            --granularity keeps only one of those three views, which is what
            makes a download summable. DAILY is the one to want; the rolling
            restatements of recent days still overlap within it, so run the
            result through scripts/summarize-refresh.py rather than adding the
            files up directly.

        STATUS:
            appstore-analytics status <REPORT_REQUEST_ID> \\
                [--report-type <REPORT_NAME>] \\
                [--watch] \\
                [--interval <SECONDS>]

        DELETE REPORT:
            appstore-analytics delete-report <REPORT_REQUEST_ID>

        SALES:
            appstore-analytics sales \\
                [--vendor-number <NUMBER>[,<NUMBER>...]]... \\
                [--frequency DAILY|WEEKLY|MONTHLY|YEARLY] \\
                [--date <REPORT_DATE>] \\
                [--last <N>] \\
                [--report-type SALES|SUBSCRIPTION|SUBSCRIPTION_EVENT|SUBSCRIBER|INSTALLS|PRE_ORDER] \\
                [--detailed] \\
                [--format table|tsv|json] \\
                [--out <FILE>]

            Sales and Trends is the transaction record: it reports exact units
            with no privacy threshold, unlike the analytics reports above, which
            omit any row covering fewer than five users or devices. Use this for
            revenue questions. --date formats are YYYY-MM-DD (daily/weekly),
            YYYY-MM (monthly), YYYY (yearly); omit it to get the last N closed
            periods. The vendor number lives in App Store Connect under Payments
            and Financial Reports — no API exposes it.

            --vendor-number is repeatable and accepts a comma-separated list. A
            vendor number belongs to a legal entity, not an app: re-incorporating
            issues a new one and history stays under the old one, so covering the
            full history means querying both.

        LIST REPORT TYPES:
            appstore-analytics list-report-types [--category <CATEGORY>]
            Categories: discovery, commerce, usage, performance, subscriptions

        REPORT TYPES:
            Discovery:
              APP_STORE_PRODUCT_PAGE_VIEWS    APP_IMPRESSIONS
              APP_STORE_SEARCH_TERMS          APP_STORE_REFERRERS
              APP_STORE_TOTAL_PAGE_VIEWS

            Commerce:
              APP_UNITS          APP_SALES           APP_PROCEEDS
              PAYING_USERS       APP_PURCHASES

            Usage:
              APP_SESSIONS       APP_INSTALLS        APP_USAGE
              ACTIVE_DEVICES     ACTIVE_LAST_30_DAYS

            Performance:
              APP_CRASHES        APP_PERFORMANCE

            Subscriptions:
              SUBSCRIPTION_EVENTS       SUBSCRIBER_ACTIVITY
              SUBSCRIPTION_RETENTION

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
