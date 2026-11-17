//
//  AnalyticsServices.swift
//  Atlas
//

import Foundation

/// What Analytics needs from App Store Connect. `LiveAnalyticsServices`
/// reads Apple; tests and DEBUG scenes swap in fakes.
@MainActor
protocol AnalyticsServices {
    /// The report requests Apple has for the app.
    func requestStatus(appID: StoreApp.ID) async throws -> AnalyticsRequestStatus
    /// Asks Apple to make the app's reports: an ongoing request, plus a
    /// one-time snapshot of earlier data. Throws `.forbidden` when the key
    /// isn't Admin. The only write Analytics makes, with `stopReports`.
    func askForReports(appID: StoreApp.ID) async throws
    func stopReports(appID: StoreApp.ID) async throws
    /// Downloads and reads the report instances not in `known`.
    func downloadEngagement(appID: StoreApp.ID, known: Set<String>) async throws -> [EngagementBatch]
    /// Reads Sales and Trends for `days` (events and charges) and
    /// `activeDays` (active subscriptions). Throws `.forbidden` when the
    /// key's role can't read sales.
    func downloadSales(vendorNumber: String, days: [AnalyticsDay], activeDays: [AnalyticsDay]) async throws -> SalesDownload
    /// A canned context instead of reading the other sections; nil reads
    /// them (the live services).
    var fixedContext: AnalyticsContext? { get }
}

extension AnalyticsServices {
    var fixedContext: AnalyticsContext? { nil }
}
