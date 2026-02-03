import Foundation

struct ListReportTypesCommand {
    static func execute(category: String?) {
        let types: [ReportType]

        if let category = category,
           let filter = ReportCategory(rawValue: category.lowercased()) {
            types = ReportType.allCases.filter { $0.category == filter }
            Logger.info("Report types for category: \(filter.rawValue)")
        } else {
            types = ReportType.allCases
            Logger.info("All available report types:")
        }

        var currentCategory: ReportCategory?
        for type in types {
            if type.category != currentCategory {
                currentCategory = type.category
                print("\n  \(type.category.rawValue.uppercased()):")
            }
            print("    \(type.rawValue.padding(toLength: 36, withPad: " ", startingAt: 0)) \(type.displayName)")
        }
        print("")
    }
}
