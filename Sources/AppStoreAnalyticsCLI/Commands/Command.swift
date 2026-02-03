import Foundation

enum Command {
    case configure(issuerId: String?, keyId: String?, privateKeyPath: String?, appId: String?)
    case createReport(reportType: String, startDate: String, endDate: String, granularity: String, wait: Bool, download: Bool, accessType: String)
    case listReports(category: String?, status: String?, format: String)
    case download(reportRequestId: String, outputDir: String?, merge: Bool, overwrite: Bool, reportType: String?)
    case status(reportRequestId: String, watch: Bool, interval: Int, reportType: String?)
    case deleteReport(reportRequestId: String)
    case listReportTypes(category: String?)
    case help
    case version

    static func parse(arguments: [String]) -> Command? {
        guard let commandName = arguments.first else {
            return .help
        }

        let args = Array(arguments.dropFirst())

        switch commandName.lowercased() {
        case "configure":
            return parseConfigureCommand(args: args)
        case "create-report":
            return parseCreateReportCommand(args: args)
        case "list-reports":
            return parseListReportsCommand(args: args)
        case "download":
            return parseDownloadCommand(args: args)
        case "status":
            return parseStatusCommand(args: args)
        case "delete-report":
            return parseDeleteReportCommand(args: args)
        case "list-report-types":
            return parseListReportTypesCommand(args: args)
        case "help", "--help", "-h":
            return .help
        case "version", "--version", "-v":
            return .version
        default:
            return nil
        }
    }

    private static func parseConfigureCommand(args: [String]) -> Command {
        var issuerId: String?
        var keyId: String?
        var privateKeyPath: String?
        var appId: String?

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--issuer-id":
                i += 1
                if i < args.count { issuerId = args[i] }
            case "--key-id":
                i += 1
                if i < args.count { keyId = args[i] }
            case "--private-key-path":
                i += 1
                if i < args.count { privateKeyPath = args[i] }
            case "--app-id":
                i += 1
                if i < args.count { appId = args[i] }
            default:
                break
            }
            i += 1
        }

        return .configure(issuerId: issuerId, keyId: keyId, privateKeyPath: privateKeyPath, appId: appId)
    }

    private static func parseCreateReportCommand(args: [String]) -> Command? {
        var reportType: String?
        var startDate: String?
        var endDate: String?
        var granularity: String = "DAILY"
        var wait = false
        var download = false
        var accessType: String = "ONE_TIME_SNAPSHOT"

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--report-type":
                i += 1
                if i < args.count { reportType = args[i] }
            case "--start-date":
                i += 1
                if i < args.count { startDate = args[i] }
            case "--end-date":
                i += 1
                if i < args.count { endDate = args[i] }
            case "--granularity":
                i += 1
                if i < args.count { granularity = args[i] }
            case "--access-type":
                i += 1
                if i < args.count { accessType = args[i].uppercased() }
            case "--ongoing":
                accessType = "ONGOING"
            case "--wait":
                wait = true
            case "--download":
                download = true
            default:
                break
            }
            i += 1
        }

        // ONGOING reports don't require date range
        if accessType == "ONGOING" {
            return .createReport(
                reportType: reportType ?? "",
                startDate: startDate ?? "",
                endDate: endDate ?? "",
                granularity: granularity,
                wait: wait,
                download: download,
                accessType: accessType
            )
        }

        guard let reportType = reportType,
              let startDate = startDate,
              let endDate = endDate else {
            return nil
        }

        return .createReport(
            reportType: reportType,
            startDate: startDate,
            endDate: endDate,
            granularity: granularity,
            wait: wait,
            download: download,
            accessType: accessType
        )
    }

    private static func parseListReportsCommand(args: [String]) -> Command {
        var category: String?
        var status: String?
        var format: String = "table"

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--category":
                i += 1
                if i < args.count { category = args[i] }
            case "--status":
                i += 1
                if i < args.count { status = args[i] }
            case "--format":
                i += 1
                if i < args.count { format = args[i] }
            default:
                break
            }
            i += 1
        }

        return .listReports(category: category, status: status, format: format)
    }

    private static func parseDownloadCommand(args: [String]) -> Command? {
        guard let reportRequestId = args.first else {
            return nil
        }

        var outputDir: String?
        var merge = false
        var overwrite = false
        var reportType: String?

        var i = 1
        while i < args.count {
            switch args[i] {
            case "--output-dir":
                i += 1
                if i < args.count { outputDir = args[i] }
            case "--merge":
                merge = true
            case "--overwrite":
                overwrite = true
            case "--report-type":
                i += 1
                if i < args.count { reportType = args[i] }
            default:
                break
            }
            i += 1
        }

        return .download(
            reportRequestId: reportRequestId,
            outputDir: outputDir,
            merge: merge,
            overwrite: overwrite,
            reportType: reportType
        )
    }

    private static func parseStatusCommand(args: [String]) -> Command? {
        guard let reportRequestId = args.first else {
            return nil
        }

        var watch = false
        var interval = 30
        var reportType: String?

        var i = 1
        while i < args.count {
            switch args[i] {
            case "--watch":
                watch = true
            case "--interval":
                i += 1
                if i < args.count, let value = Int(args[i]) {
                    interval = value
                }
            case "--report-type":
                i += 1
                if i < args.count { reportType = args[i] }
            default:
                break
            }
            i += 1
        }

        return .status(reportRequestId: reportRequestId, watch: watch, interval: interval, reportType: reportType)
    }

    private static func parseDeleteReportCommand(args: [String]) -> Command? {
        guard let reportRequestId = args.first else {
            return nil
        }
        return .deleteReport(reportRequestId: reportRequestId)
    }

    private static func parseListReportTypesCommand(args: [String]) -> Command {
        var category: String?

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--category":
                i += 1
                if i < args.count { category = args[i] }
            default:
                break
            }
            i += 1
        }

        return .listReportTypes(category: category)
    }
}
