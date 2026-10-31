import Foundation

struct ListReportTypesCommand {
    static func execute(category: String?) {
        let types: [ReportType]

        if let category = category,
           let filter = LegacyReportGroup(rawValue: category.lowercased()) {
            types = ReportType.allCases.filter { $0.group == filter }
            Logger.info("Report types for category: \(filter.rawValue)")
        } else {
            types = ReportType.allCases
            Logger.info("All available report types:")
        }

        var currentGroup: LegacyReportGroup?
        for type in types {
            if type.group != currentGroup {
                currentGroup = type.group
                print("\n  \(type.group.rawValue.uppercased()):")
            }
            print("    \(type.rawValue.padding(toLength: 36, withPad: " ", startingAt: 0)) \(type.displayName)")
        }
        print("")
    }
}
