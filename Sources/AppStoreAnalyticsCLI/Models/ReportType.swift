import Foundation

enum ReportCategory: String, CaseIterable {
    case discovery = "discovery"
    case engagement = "engagement"
    case commerce = "commerce"
    case usage = "usage"
    case performance = "performance"
    case subscriptions = "subscriptions"
}

enum ReportType: String, CaseIterable {
    // Discovery Reports
    case appStoreProductPageViews = "APP_STORE_PRODUCT_PAGE_VIEWS"
    case appStoreSearchTerms = "APP_STORE_SEARCH_TERMS"
    case appImpressions = "APP_IMPRESSIONS"
    case appStoreReferrers = "APP_STORE_REFERRERS"
    case appStoreTotalPageViews = "APP_STORE_TOTAL_PAGE_VIEWS"

    // Commerce Reports
    case appUnits = "APP_UNITS"
    case appSales = "APP_SALES"
    case appProceeds = "APP_PROCEEDS"
    case payingUsers = "PAYING_USERS"
    case appPurchases = "APP_PURCHASES"

    // Usage Reports
    case appSessions = "APP_SESSIONS"
    case appInstalls = "APP_INSTALLS"
    case appUsage = "APP_USAGE"
    case activeDevices = "ACTIVE_DEVICES"
    case activeLast30Days = "ACTIVE_LAST_30_DAYS"

    // Performance Reports
    case appCrashes = "APP_CRASHES"
    case appPerformance = "APP_PERFORMANCE"

    // Subscription Reports
    case subscriptionEvents = "SUBSCRIPTION_EVENTS"
    case subscriberActivity = "SUBSCRIBER_ACTIVITY"
    case subscriptionRetention = "SUBSCRIPTION_RETENTION"

    var category: ReportCategory {
        switch self {
        case .appStoreProductPageViews, .appStoreSearchTerms, .appImpressions,
             .appStoreReferrers, .appStoreTotalPageViews:
            return .discovery

        case .appUnits, .appSales, .appProceeds, .payingUsers, .appPurchases:
            return .commerce

        case .appSessions, .appInstalls, .appUsage, .activeDevices, .activeLast30Days:
            return .usage

        case .appCrashes, .appPerformance:
            return .performance

        case .subscriptionEvents, .subscriberActivity, .subscriptionRetention:
            return .subscriptions
        }
    }

    var displayName: String {
        switch self {
        case .appStoreProductPageViews: return "App Store Product Page Views"
        case .appStoreSearchTerms: return "App Store Search Terms"
        case .appImpressions: return "App Impressions"
        case .appStoreReferrers: return "App Store Referrers"
        case .appStoreTotalPageViews: return "App Store Total Page Views"
        case .appUnits: return "App Units"
        case .appSales: return "App Sales"
        case .appProceeds: return "App Proceeds"
        case .payingUsers: return "Paying Users"
        case .appPurchases: return "App Purchases"
        case .appSessions: return "App Sessions"
        case .appInstalls: return "App Installs"
        case .appUsage: return "App Usage"
        case .activeDevices: return "Active Devices"
        case .activeLast30Days: return "Active Last 30 Days"
        case .appCrashes: return "App Crashes"
        case .appPerformance: return "App Performance"
        case .subscriptionEvents: return "Subscription Events"
        case .subscriberActivity: return "Subscriber Activity"
        case .subscriptionRetention: return "Subscription Retention"
        }
    }
}

enum Granularity: String {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
}

enum ReportStatus: String, Codable {
    case created = "CREATED"
    case processing = "PROCESSING"
    case completed = "COMPLETED"
    case failed = "FAILED"
}
