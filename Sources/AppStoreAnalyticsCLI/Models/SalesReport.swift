import Foundation

/// One row of an App Store Connect Sales and Trends report.
///
/// The report is a tab-separated file whose column set varies by report type
/// and Apple's own revisions, so rows keep the raw field dictionary and expose
/// only the columns this tool actually uses.
struct SalesReportRow {
    let fields: [String: String]

    subscript(column: String) -> String? {
        fields[column]
    }

    var sku: String { fields["SKU"] ?? "" }
    var title: String { fields["Title"] ?? "" }
    var productTypeIdentifier: String { fields["Product Type Identifier"] ?? "" }
    var units: Int { Int(fields["Units"] ?? "") ?? 0 }
    var developerProceeds: Decimal { Decimal(string: fields["Developer Proceeds"] ?? "") ?? 0 }
    var currencyOfProceeds: String { fields["Currency of Proceeds"] ?? "" }
    var countryCode: String { fields["Country Code"] ?? "" }
    var beginDate: String { fields["Begin Date"] ?? "" }

    /// Apple's in-app purchase product types all start with "IA" — IA1 and IAY
    /// for purchases, IAC for subscriptions, and so on. Everything else (1, 1F,
    /// 7, F1, …) is an app download, update, or re-download.
    var isInAppPurchase: Bool {
        productTypeIdentifier.hasPrefix("IA")
    }
}

/// Units and proceeds for one product, summed across every row that shares a
/// SKU — reports break the same product out per territory and per day.
struct SalesLineItem {
    let sku: String
    let title: String
    let productTypeIdentifier: String
    let isInAppPurchase: Bool
    var units: Int
    var proceeds: Decimal
    var currencies: Set<String>
}

struct SalesSummary {
    let lineItems: [SalesLineItem]
    let periodsCovered: [String]
    let periodsWithNoData: [String]

    var inAppPurchases: [SalesLineItem] { lineItems.filter(\.isInAppPurchase) }
    var appDownloads: [SalesLineItem] { lineItems.filter { !$0.isInAppPurchase } }

    var totalInAppPurchaseUnits: Int {
        inAppPurchases.reduce(0) { $0 + $1.units }
    }

    var totalProceeds: Decimal {
        lineItems.reduce(0) { $0 + $1.proceeds }
    }

    /// Proceeds only mean something as a single number when one currency is
    /// involved; Apple reports each territory in its own settlement currency.
    var currencies: Set<String> {
        lineItems.reduce(into: Set<String>()) { $0.formUnion($1.currencies) }
    }

    var isEmpty: Bool { lineItems.isEmpty }
}
