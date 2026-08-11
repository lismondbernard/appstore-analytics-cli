import Foundation
import AppStoreConnect_Swift_SDK

enum SalesCommandError: LocalizedError {
    case missingVendorNumber
    case invalidFrequency(String)
    case invalidReportType(String)

    var errorDescription: String? {
        switch self {
        case .missingVendorNumber:
            return """
            No vendor number configured. Pass --vendor-number <NUMBER>, or add it \
            with 'appstore-analytics configure'. Find it in App Store Connect under \
            Payments and Financial Reports — the API has no endpoint that exposes it.
            """
        case .invalidFrequency(let value):
            return "Invalid frequency '\(value)'. Expected DAILY, WEEKLY, MONTHLY, or YEARLY."
        case .invalidReportType(let value):
            return "Invalid report type '\(value)'. Expected SALES, SUBSCRIPTION, SUBSCRIPTION_EVENT, or SUBSCRIBER."
        }
    }
}

/// Reports actual units and proceeds from Sales and Trends.
///
/// This is the counterpart to the analytics commands, and the one to trust for
/// revenue: analytics reports omit any row covering fewer than five users or
/// devices, so a handful of purchases simply never appears there.
struct SalesCommand {
    static func execute(
        vendorNumbers requestedVendors: [String],
        frequency: String,
        reportDate: String?,
        last: Int,
        reportType: String,
        detailed: Bool,
        format: String,
        outputPath: String?
    ) async throws {
        let configuration = try ConfigManager.shared.loadConfiguration()

        let vendors = requestedVendors.isEmpty ? configuration.vendorNumbers : requestedVendors
        guard !vendors.isEmpty else {
            throw SalesCommandError.missingVendorNumber
        }

        guard let frequencyValue = SalesReportPeriod.Frequency(rawValue: frequency.uppercased()) else {
            throw SalesCommandError.invalidFrequency(frequency)
        }

        let sdkReportType: APIEndpoint.V1.SalesReports.GetParameters.FilterReportType
        switch reportType.uppercased() {
        case "SALES": sdkReportType = .sales
        case "SUBSCRIPTION": sdkReportType = .subscription
        case "SUBSCRIPTION_EVENT": sdkReportType = .subscriptionEvent
        case "SUBSCRIBER": sdkReportType = .subscriber
        case "INSTALLS": sdkReportType = .installs
        case "PRE_ORDER": sdkReportType = .preOrder
        default: throw SalesCommandError.invalidReportType(reportType)
        }

        let periods = reportDate.map { [$0] }
            ?? SalesReportPeriod.recent(last, frequency: frequencyValue)

        guard !periods.isEmpty else {
            Logger.error("No closed \(frequencyValue.rawValue.lowercased()) period to request yet.")
            return
        }

        let client = try APIClient(configuration: configuration)

        Logger.info(
            "Fetching \(periods.count) \(frequencyValue.rawValue.lowercased()) \(reportType) report(s) "
            + "across \(vendors.count) vendor number(s): \(vendors.joined(separator: ", "))..."
        )

        var rowsByVendor: [(vendor: String, rows: [SalesReportRow])] = []
        var covered = Set<String>()
        var inaccessible: [String] = []
        var rawReports: [String] = []

        for vendor in vendors {
            var vendorRows: [SalesReportRow] = []
            var vendorAuthorized = true

            for period in periods {
                let fetched = try await client.fetchSalesReport(
                    vendorNumber: vendor,
                    frequency: frequencyValue,
                    reportDate: period,
                    reportType: sdkReportType,
                    subType: detailed ? .detailed : .summary
                )

                switch fetched {
                case .report(let text):
                    covered.insert(period)
                    rawReports.append(text)
                    vendorRows.append(contentsOf: SalesReportParser.parseRows(text))
                case .noReport:
                    // Expected: each vendor only has data for the periods when
                    // that legal entity was the one selling.
                    continue
                case .notAuthorized:
                    vendorAuthorized = false
                }

                if !vendorAuthorized { break }
            }

            if vendorAuthorized {
                rowsByVendor.append((vendor: vendor, rows: vendorRows))
            } else {
                inaccessible.append(vendor)
                Logger.error("Vendor \(vendor) is not readable with the configured API key.")
                Logger.info("If that entity is a separate App Store Connect account, it needs its own key.")
            }
        }

        // Periods with no data from any vendor.
        let empty = periods.filter { !covered.contains($0) }

        let summary = SalesReportParser.summarize(
            rowsByVendor: rowsByVendor,
            periodsCovered: periods.filter { covered.contains($0) },
            periodsWithNoData: empty,
            inaccessibleVendors: inaccessible
        )

        let output: String
        switch format.lowercased() {
        case "tsv":
            output = rawReports.joined(separator: "\n")
        case "json":
            output = renderJSON(summary)
        default:
            output = renderTable(summary)
        }

        if let outputPath {
            let expanded = UserInput.expandTildePath(outputPath)
            try (output + "\n").write(toFile: expanded, atomically: true, encoding: .utf8)
            Logger.success("Wrote \(expanded)")
        } else {
            print(output)
        }
    }

    // MARK: - Rendering

    private static func renderTable(_ summary: SalesSummary) -> String {
        var lines: [String] = []

        if !summary.inaccessibleVendors.isEmpty {
            // Say this loudly: a silently skipped vendor makes the totals wrong
            // rather than merely incomplete.
            lines.append("INCOMPLETE — no access to vendor(s): \(summary.inaccessibleVendors.joined(separator: ", "))")
            lines.append("")
        }

        if !summary.periodsWithNoData.isEmpty {
            lines.append("No report for: \(summary.periodsWithNoData.joined(separator: ", "))")
            lines.append("")
        }

        guard !summary.isEmpty else {
            lines.append("No sales in \(summary.periodsCovered.isEmpty ? "the requested period(s)" : summary.periodsCovered.joined(separator: ", ")).")
            lines.append("")
            lines.append("Sales and Trends is exact — this is a real zero, not a privacy threshold.")
            return lines.joined(separator: "\n")
        }

        lines.append("Periods: \(summary.periodsCovered.joined(separator: ", "))")
        lines.append("")

        let width = max(summary.lineItems.map(\.title.count).max() ?? 0, 5)
        let skuWidth = max(summary.lineItems.map(\.sku.count).max() ?? 0, 3)

        lines.append(
            "\(pad("Title", width))  \(pad("SKU", skuWidth))  \(pad("Type", 4))  \(padLeft("Units", 7))  \(padLeft("Proceeds", 12))"
        )
        lines.append(String(repeating: "-", count: width + skuWidth + 4 + 7 + 12 + 8))

        for item in summary.lineItems {
            let currency = item.currencies.count == 1 ? " \(item.currencies.first!)" : ""
            lines.append(
                "\(pad(item.title, width))  \(pad(item.sku, skuWidth))  \(pad(item.productTypeIdentifier, 4))  \(padLeft(String(item.units), 7))  \(padLeft("\(item.proceeds)\(currency)", 12))"
            )
        }

        lines.append("")
        lines.append("In-app purchase units: \(summary.totalInAppPurchaseUnits)")

        if summary.vendors.count > 1 {
            for vendor in summary.vendors.sorted() {
                let units = summary.lineItems
                    .filter { $0.vendors.contains(vendor) && $0.isInAppPurchase }
                    .reduce(0) { $0 + $1.units }
                lines.append("  vendor \(vendor): \(units)")
            }
        }

        if summary.currencies.count > 1 {
            // Summing across settlement currencies would invent a number.
            lines.append("Proceeds span \(summary.currencies.sorted().joined(separator: ", ")) — not summed.")
        } else if let currency = summary.currencies.first {
            lines.append("Total proceeds: \(summary.totalProceeds) \(currency)")
        }

        return lines.joined(separator: "\n")
    }

    private static func renderJSON(_ summary: SalesSummary) -> String {
        let payload: [String: Any] = [
            "periods_covered": summary.periodsCovered,
            "periods_with_no_data": summary.periodsWithNoData,
            "inaccessible_vendors": summary.inaccessibleVendors,
            "in_app_purchase_units": summary.totalInAppPurchaseUnits,
            "currencies": summary.currencies.sorted(),
            "line_items": summary.lineItems.map { item in
                [
                    "title": item.title,
                    "sku": item.sku,
                    "product_type_identifier": item.productTypeIdentifier,
                    "is_in_app_purchase": item.isInAppPurchase,
                    "units": item.units,
                    "proceeds": "\(item.proceeds)",
                    "currencies": item.currencies.sorted(),
                    "vendors": item.vendors.sorted(),
                ]
            },
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    private static func padLeft(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
    }
}
