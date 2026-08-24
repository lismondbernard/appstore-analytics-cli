import Foundation

/// Describes what each downloaded instance directory contains.
///
/// The download layout — `{report-id}/instance-{id}/segment-NNN.csv` — records
/// neither the report an instance belongs to nor its granularity, and neither
/// is recoverable from the CSVs. Report name can be guessed from the header
/// shape, but granularity cannot: a one-row instance holding a single date is
/// indistinguishable between one day of a DAILY report and one bucket of a
/// WEEKLY one. Getting that wrong either drops real data or triple-counts it,
/// so `download` writes this file next to the instance directories.
struct DownloadManifest: Codable {
    let reportRequestId: String
    let instances: [Entry]

    struct Entry: Codable {
        let instanceId: String
        /// Directory name relative to the manifest, so a reader can join paths
        /// without reconstructing the `instance-` prefix.
        let directory: String
        let reportName: String?
        let reportCategory: String?
        /// `DAILY`, `WEEKLY`, `MONTHLY`, or `UNKNOWN` when the API omitted it.
        let granularity: String
        let processingDate: String?

        enum CodingKeys: String, CodingKey {
            case instanceId = "instance_id"
            case directory
            case reportName = "report_name"
            case reportCategory = "report_category"
            case granularity
            case processingDate = "processing_date"
        }
    }

    enum CodingKeys: String, CodingKey {
        case reportRequestId = "report_request_id"
        case instances
    }
}
