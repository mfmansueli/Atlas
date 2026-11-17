//
//  DebugAnalyticsServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Analytics without Apple: asking succeeds (or is refused for the key's
/// role), and downloads bring nothing, since scenes load their facts into
/// the store directly.
struct DebugAnalyticsServices: AnalyticsServices {
    /// Asking is refused as for an App Manager key.
    var keyCannotAsk = false
    /// A download that never ends, for the loading scene.
    var neverFinishes = false
    var fixedContext: AnalyticsContext? = DebugAnalyticsData.context

    func requestStatus(appID _: StoreApp.ID) async throws -> AnalyticsRequestStatus {
        if neverFinishes { try await Task.sleep(for: .seconds(3600)) }
        return AnalyticsRequestStatus(requestIDs: ["debug"], hasOngoing: true)
    }

    func askForReports(appID _: StoreApp.ID) async throws {
        if keyCannotAsk { throw AppStoreConnectError.forbidden(detail: nil) }
    }

    func stopReports(appID _: StoreApp.ID) async throws {}

    func downloadEngagement(appID _: StoreApp.ID, known _: Set<String>) async throws -> [EngagementBatch] { [] }

    func downloadSales(vendorNumber _: String, days _: [AnalyticsDay], activeDays _: [AnalyticsDay]) async throws -> SalesDownload {
        SalesDownload()
    }
}
#endif
