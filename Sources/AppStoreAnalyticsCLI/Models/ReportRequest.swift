import Foundation

struct AnalyticsReportRequest: Codable {
    let id: String
    let reportType: String
    let reportSubType: String?
    let accessType: String?
    let stoppedDueToInactivity: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case reportType = "report_type"
        case reportSubType = "report_sub_type"
        case accessType = "access_type"
        case stoppedDueToInactivity = "stopped_due_to_inactivity"
    }
}

struct AnalyticsReportRequestCreateParams {
    let accessType: String
    let app: String
    let reportType: String
    let reportSubType: String
    let frequency: String
    let vendorNumber: String

    func toRequestBody() -> [String: Any] {
        return [
            "data": [
                "type": "analyticsReportRequests",
                "attributes": [
                    "accessType": accessType,
                    "reportType": reportType,
                    "reportSubType": reportSubType,
                    "frequency": frequency,
                    "vendorNumber": vendorNumber
                ],
                "relationships": [
                    "app": [
                        "data": [
                            "type": "apps",
                            "id": app
                        ]
                    ]
                ]
            ]
        ]
    }
}

struct AnalyticsReport: Codable {
    let id: String
    let name: String
    let category: String?
    let instancesUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case instancesUrl = "instances_url"
    }
}

struct AnalyticsReportInstance: Codable {
    let id: String
    let granularity: String
    let processingDate: String?
    let segmentsUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case granularity
        case processingDate = "processing_date"
        case segmentsUrl = "segments_url"
    }
}

struct AnalyticsReportSegment: Codable {
    let id: String
    let url: String?
    let checksum: String?
    let sizeInBytes: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case checksum
        case sizeInBytes = "size_in_bytes"
    }
}
