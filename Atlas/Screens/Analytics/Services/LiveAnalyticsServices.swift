//
//  LiveAnalyticsServices.swift
//  Atlas
//

import Foundation

/// Analytics against App Store Connect: the Analytics Reports API for the
/// store page, Sales and Trends for subscriptions.
struct LiveAnalyticsServices: AnalyticsServices {
    let client: AppStoreConnectClient

    /// Reports read at once; Apple allows about 3,600 requests an hour.
    private static let width = 6

    func requestStatus(appID: StoreApp.ID) async throws -> AnalyticsRequestStatus {
        let requests = try await client.analyticsReportRequests(appID: appID)
        let live = requests.filter { $0.attributes.stoppedDueToInactivity != true }
        return AnalyticsRequestStatus(
            requestIDs: live.map(\.id),
            hasOngoing: live.contains { $0.attributes.accessType == "ONGOING" }
        )
    }

    func askForReports(appID: StoreApp.ID) async throws {
        let existing = try await client.analyticsReportRequests(appID: appID).filter { $0.attributes.stoppedDueToInactivity != true }
        if !existing.contains(where: { $0.attributes.accessType == "ONGOING" }) {
            try await client.createAnalyticsReportRequest(appID: appID, accessType: "ONGOING")
        }
        // Earlier data, so periods can be compared as soon as the first
        // report lands. Apple allows one a month: a refusal isn't a failure.
        if !existing.contains(where: { $0.attributes.accessType == "ONE_TIME_SNAPSHOT" }) {
            do {
                try await client.createAnalyticsReportRequest(appID: appID, accessType: "ONE_TIME_SNAPSHOT")
            } catch AppStoreConnectError.rejected {}
        }
    }

    func stopReports(appID: StoreApp.ID) async throws {
        for request in try await client.analyticsReportRequests(appID: appID) {
            try await client.deleteAnalyticsReportRequest(id: request.id)
        }
    }

    func downloadEngagement(appID: StoreApp.ID, known: Set<String>) async throws -> [EngagementBatch] {
        let client = client
        let requests = try await client.analyticsReportRequests(appID: appID).filter { $0.attributes.stoppedDueToInactivity != true }
        var pending: [PendingInstance] = []
        for request in requests {
            for kind in EngagementReportKind.allCases {
                let reports = try await client.analyticsReports(requestID: request.id, category: kind.category)
                for report in reports {
                    guard let name = report.attributes.name, kind.matches(reportName: name) else { continue }
                    let isDetailed = name.lowercased().contains("detailed")
                    for instance in try await client.analyticsReportInstances(reportID: report.id) where !known.contains(instance.id) {
                        guard let processing = instance.attributes.processingDate.flatMap(AnalyticsDay.init(iso:)) else { continue }
                        pending.append(PendingInstance(id: instance.id, kind: kind, isDetailed: isDetailed, processing: processing))
                    }
                }
            }
        }
        return try await withThrowingTaskGroup(of: EngagementBatch.self) { group in
            var batches: [EngagementBatch] = []
            var iterator = pending.makeIterator()
            var running = 0
            while running < Self.width, let instance = iterator.next() {
                group.addTask { try await Self.read(instance, appID: appID, client: client) }
                running += 1
            }
            while let batch = try await group.next() {
                batches.append(batch)
                if let instance = iterator.next() {
                    group.addTask { try await Self.read(instance, appID: appID, client: client) }
                }
            }
            return batches
        }
    }

    func downloadSales(vendorNumber: String, days: [AnalyticsDay], activeDays: [AnalyticsDay]) async throws -> SalesDownload {
        let client = client
        let jobs = days.map { SalesJob(day: $0, isActive: false) } + activeDays.map { SalesJob(day: $0, isActive: true) }
        return try await withThrowingTaskGroup(of: SalesDownload.self) { group in
            var result = SalesDownload()
            var iterator = jobs.makeIterator()
            var running = 0
            while running < Self.width, let job = iterator.next() {
                group.addTask { try await Self.read(job, vendorNumber: vendorNumber, client: client) }
                running += 1
            }
            while let part = try await group.next() {
                result.days += part.days
                result.events += part.events
                result.subscribers += part.subscribers
                result.activeDays += part.activeDays
                result.active += part.active
                if let job = iterator.next() {
                    group.addTask { try await Self.read(job, vendorNumber: vendorNumber, client: client) }
                }
            }
            return result
        }
    }

    private struct PendingInstance: Sendable {
        var id: String
        var kind: EngagementReportKind
        var isDetailed: Bool
        var processing: AnalyticsDay
    }

    private struct SalesJob: Sendable {
        var day: AnalyticsDay
        var isActive: Bool
    }

    /// Every segment of one instance, read into facts.
    private static func read(_ instance: PendingInstance, appID: String, client: AppStoreConnectClient) async throws -> EngagementBatch {
        var facts: [EngagementFact] = []
        for segment in try await client.analyticsReportSegments(instanceID: instance.id) {
            guard let url = segment.attributes.url else { continue }
            guard let table = try await DelimitedTable(data: client.downloadAnalyticsSegment(url)) else {
                throw AppStoreConnectError.unexpectedPayload
            }
            switch instance.kind {
            case .engagement: facts += EngagementReportParser.engagement(table, appID: appID)
            case .downloads: facts += EngagementReportParser.downloads(table, appID: appID)
            }
        }
        return EngagementBatch(
            instanceID: instance.id, kind: instance.kind, isDetailed: instance.isDetailed, processing: instance.processing,
            facts: EngagementFact.merged(facts)
        )
    }

    private static func read(_ job: SalesJob, vendorNumber: String, client: AppStoreConnectClient) async throws -> SalesDownload {
        let date = job.day.iso
        var result = SalesDownload()
        if job.isActive {
            result.activeDays = [job.day]
            if let data = try await client.salesReport(vendorNumber: vendorNumber, type: "SUBSCRIPTION", subType: "SUMMARY", version: "1_3", date: date),
               let table = DelimitedTable(data: data)
            {
                result.active = SalesReportParser.active(table, day: job.day)
            }
            return result
        }
        result.days = [job.day]
        if let data = try await client.salesReport(vendorNumber: vendorNumber, type: "SUBSCRIPTION_EVENT", subType: "SUMMARY", version: "1_3", date: date),
           let table = DelimitedTable(data: data)
        {
            result.events = SalesReportParser.events(table, fallbackDay: job.day)
        }
        if let data = try await client.salesReport(vendorNumber: vendorNumber, type: "SUBSCRIBER", subType: "DETAILED", version: "1_3", date: date),
           let table = DelimitedTable(data: data)
        {
            result.subscribers = SalesReportParser.subscribers(table, fallbackDay: job.day)
        }
        return result
    }
}
