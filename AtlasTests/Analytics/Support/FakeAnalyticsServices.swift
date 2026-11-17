//
//  FakeAnalyticsServices.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Analytics services that answer from what the test sets, and remember
/// what was asked.
@MainActor
final class FakeAnalyticsServices: AnalyticsServices {
    var status = AnalyticsRequestStatus(requestIDs: ["r1"], hasOngoing: true)
    var askError: (any Error)?
    var salesError: (any Error)?
    var batches: [EngagementBatch] = []
    var sales = SalesDownload()
    private(set) var asked: [StoreApp.ID] = []
    private(set) var stopped: [StoreApp.ID] = []
    private(set) var knownInstances: [Set<String>] = []
    private(set) var salesDays: [[AnalyticsDay]] = []
    private(set) var activeDays: [[AnalyticsDay]] = []

    func requestStatus(appID _: StoreApp.ID) async throws -> AnalyticsRequestStatus { status }

    func askForReports(appID: StoreApp.ID) async throws {
        if let askError { throw askError }
        asked.append(appID)
    }

    func stopReports(appID: StoreApp.ID) async throws {
        stopped.append(appID)
    }

    func downloadEngagement(appID _: StoreApp.ID, known: Set<String>) async throws -> [EngagementBatch] {
        knownInstances.append(known)
        return batches.filter { !known.contains($0.instanceID) }
    }

    func downloadSales(vendorNumber _: String, days: [AnalyticsDay], activeDays: [AnalyticsDay]) async throws -> SalesDownload {
        if let salesError { throw salesError }
        salesDays.append(days)
        self.activeDays.append(activeDays)
        var download = sales
        download.days = days
        download.activeDays = activeDays
        return download
    }
}
