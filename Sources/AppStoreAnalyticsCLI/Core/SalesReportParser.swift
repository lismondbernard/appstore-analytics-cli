import Foundation

/// Parses Apple's tab-separated Sales and Trends reports.
///
/// Unlike the Analytics reports, these are exact: Sales and Trends is the
/// record of what was actually bought, so no privacy threshold is applied and
/// a single unit shows up as a single unit.
enum SalesReportParser {
    static func parseRows(_ text: String) -> [SalesReportRow] {
        // Apple ships CRLF; the trailing line is often a blank or a total.
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        guard let header = lines.first else { return [] }
        let columns = header.components(separatedBy: "\t")

        return lines.dropFirst().compactMap { line in
            let values = line.components(separatedBy: "\t")
            // Apple appends a plain-text total line on some report types; it
            // has nothing to do with the column layout.
            guard values.count == columns.count else { return nil }

            var fields: [String: String] = [:]
            for (column, value) in zip(columns, values) {
                fields[column.trimmingCharacters(in: .whitespaces)] = value.trimmingCharacters(in: .whitespaces)
            }
            return SalesReportRow(fields: fields)
        }
    }

    /// Collapses rows to one line item per SKU, summing units and proceeds.
    static func summarize(
        rows: [SalesReportRow],
        periodsCovered: [String] = [],
        periodsWithNoData: [String] = []
    ) -> SalesSummary {
        var bySKU: [String: SalesLineItem] = [:]

        for row in rows {
            // Key on product type too: an app and its IAP can share a SKU stem
            // and must never be merged into one line.
            let key = "\(row.sku)|\(row.productTypeIdentifier)"

            if var existing = bySKU[key] {
                existing.units += row.units
                existing.proceeds += row.developerProceeds * Decimal(row.units)
                if !row.currencyOfProceeds.isEmpty {
                    existing.currencies.insert(row.currencyOfProceeds)
                }
                bySKU[key] = existing
            } else {
                bySKU[key] = SalesLineItem(
                    sku: row.sku,
                    title: row.title,
                    productTypeIdentifier: row.productTypeIdentifier,
                    isInAppPurchase: row.isInAppPurchase,
                    units: row.units,
                    // "Developer Proceeds" is per unit, so a row of 3 units at
                    // $0.70 is $2.10 — summing the column alone undercounts.
                    proceeds: row.developerProceeds * Decimal(row.units),
                    currencies: row.currencyOfProceeds.isEmpty ? [] : [row.currencyOfProceeds]
                )
            }
        }

        let sorted = bySKU.values.sorted {
            $0.units == $1.units ? $0.sku < $1.sku : $0.units > $1.units
        }

        return SalesSummary(
            lineItems: sorted,
            periodsCovered: periodsCovered,
            periodsWithNoData: periodsWithNoData
        )
    }
}
