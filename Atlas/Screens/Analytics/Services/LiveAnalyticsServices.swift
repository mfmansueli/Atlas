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
        try await Self.checkVendorNumber(vendorNumber, before: days + activeDays, client: client)
        let jobs = days.map { SalesJob(day: $0, isActive: false) } + activeDays.map { SalesJob(day: $0, isActive: true) }
        return try await withThrowingTaskGroup(of: SalesDownload.self) { group in
            var result = SalesDownload()
            var iterator = jobs.makeIterator()
            var running = 0
            while running < Self.width, let job = iterator.next() {
                group.addTask { try await Self.readKeepingFailure(job, vendorNumber: vendorNumber, client: client) }
                running += 1
            }
            while let part = try await group.next() {
                result.days += part.days
                result.events += part.events
                result.subscribers += part.subscribers
                result.activeDays += part.activeDays
                result.active += part.active
                result.failedDays += part.failedDays
                result.failure = result.failure ?? part.failure
                if let job = iterator.next() {
                    group.addTask { try await Self.readKeepingFailure(job, vendorNumber: vendorNumber, client: client) }
                }
            }
            return result
        }
    }

    func downloadReports(appID: StoreApp.ID, known: Set<String>) async throws -> ReportsDownload {
        let client = client
        let requests = try await client.analyticsReportRequests(appID: appID).filter { $0.attributes.stoppedDueToInactivity != true }
        var listed: [AppleReportKind: Int] = [:]
        var pending: [PendingReport] = []
        for request in requests {
            let reports = try await client.analyticsReports(requestID: request.id, category: nil)
            // The Detailed report has every column the Standard one has, and
            // the page and campaign: read only it when Apple makes both.
            let matched = reports.compactMap { report -> (String, AppleReportKind, Bool)? in
                guard let name = report.attributes.name, let kind = AppleReportKind.kind(reportName: name) else { return nil }
                return (report.id, kind, name.lowercased().contains("detailed"))
            }
            let detailedKinds = Set(matched.filter(\.2).map(\.1))
            for (reportID, kind, isDetailed) in matched where isDetailed || !detailedKinds.contains(kind) {
                let instances = try await client.analyticsReportInstances(reportID: reportID)
                listed[kind, default: 0] += instances.count
                for instance in instances where !known.contains(instance.id) {
                    guard let processing = instance.attributes.processingDate.flatMap(AnalyticsDay.init(iso:)) else { continue }
                    pending.append(PendingReport(id: instance.id, kind: kind, processing: processing))
                }
            }
        }
        let batches = try await withThrowingTaskGroup(of: ReportBatch.self) { group in
            var batches: [ReportBatch] = []
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
        return ReportsDownload(batches: batches, listed: listed)
    }

    func gracePeriod(appID: StoreApp.ID) async throws -> GracePeriodSetting? {
        guard let resource = try await client.subscriptionGracePeriod(appID: appID) else { return nil }
        return GracePeriodSetting(
            id: resource.id, isOn: resource.attributes.optIn == true,
            duration: resource.attributes.duration.flatMap(GracePeriodSetting.Duration.init(rawValue:))
        )
    }

    func turnOnGracePeriod(_ setting: GracePeriodSetting, duration: GracePeriodSetting.Duration) async throws {
        try await client.turnOnSubscriptionGracePeriod(id: setting.id, duration: duration.rawValue)
    }

    private struct PendingReport: Sendable {
        var id: String
        var kind: AppleReportKind
        var processing: AnalyticsDay
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

    /// Every segment of one newer report's instance, read into facts.
    private static func read(_ instance: PendingReport, appID: String, client: AppStoreConnectClient) async throws -> ReportBatch {
        var facts: [ReportFact] = []
        for segment in try await client.analyticsReportSegments(instanceID: instance.id) {
            guard let url = segment.attributes.url else { continue }
            guard let table = try await DelimitedTable(data: client.downloadAnalyticsSegment(url)) else {
                throw AppStoreConnectError.unexpectedPayload
            }
            facts += AppleReportParser.facts(table, kind: instance.kind, appID: appID)
        }
        return ReportBatch(instanceID: instance.id, kind: instance.kind, processing: instance.processing, facts: ReportFact.merged(facts))
    }

    /// One day's reports. A day that fails no longer throws the whole read
    /// away (Alba's 180 days were lost to it): it's left unread and named,
    /// and the days that loaded are kept. A key that's refused stops all.
    private static func readKeepingFailure(_ job: SalesJob, vendorNumber: String, client: AppStoreConnectClient) async throws -> SalesDownload {
        do {
            return try await read(job, vendorNumber: vendorNumber, client: client)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AppStoreConnectError where stopsEveryDay(error) {
            throw error
        } catch {
            var failed = SalesDownload()
            if !job.isActive { failed.failedDays = [job.day] }
            failed.failure = AppleErrorCopy(String(localized: "Sales didn’t load.", comment: "kind:error"), error: error)
            return failed
        }
    }

    /// A refused or unknown key fails every day the same way.
    private static func stopsEveryDay(_ error: AppStoreConnectError) -> Bool {
        switch error {
        case .unauthorized, .forbidden: true
        default: false
        }
    }

    /// Apple answers "Invalid vendor number specified" (400) to the
    /// subscriber and active-subscription reports of a vendor with nobody
    /// subscribed yet, though the same number reads the event report.
    /// The event report still fails on a number that's really wrong.
    private static func meansNobodySubscribed(_ error: any Error) -> Bool {
        guard case let AppStoreConnectError.server(statusCode, code, detail) = error, statusCode == 400 else { return false }
        return (code ?? "").hasPrefix("PARAMETER_ERROR.INVALID") && (detail ?? "").localizedCaseInsensitiveContains("vendor")
    }

    /// Apple's subscription reports answer "Invalid vendor number" both to
    /// a wrong number and to a vendor nobody subscribed to yet (Alba). The
    /// Sales report tells them apart: it knows every vendor that has
    /// downloads, so a number it takes is right and the 400s mean "no
    /// subscriptions yet".
    private static func checkVendorNumber(_ vendorNumber: String, before days: [AnalyticsDay], client: AppStoreConnectClient) async throws {
        guard let newest = days.max() else { return }
        do {
            _ = try await client.salesReport(vendorNumber: vendorNumber, type: "SALES", subType: "SUMMARY", version: "1_0", date: newest.adding(-1).iso)
        } catch where meansNobodySubscribed(error) {
            throw SalesVendorNumberError(vendorNumber: vendorNumber)
        }
    }

    /// A report that's empty for a vendor nobody subscribed to yet.
    private static func optionalReport(_ read: () async throws -> Data?) async throws -> Data? {
        do {
            return try await read()
        } catch where meansNobodySubscribed(error) {
            return nil
        }
    }

    private static func read(_ job: SalesJob, vendorNumber: String, client: AppStoreConnectClient) async throws -> SalesDownload {
        let date = job.day.iso
        func report(_ type: String, _ subType: String) async throws -> DelimitedTable? {
            let data = try await optionalReport {
                try await client.salesReport(vendorNumber: vendorNumber, type: type, subType: subType, version: "1_3", date: date)
            }
            return data.flatMap(DelimitedTable.init(data:))
        }
        var result = SalesDownload()
        if job.isActive {
            result.activeDays = [job.day]
            if let table = try await report("SUBSCRIPTION", "SUMMARY") {
                result.active = SalesReportParser.active(table, day: job.day)
            }
            return result
        }
        result.days = [job.day]
        if let table = try await report("SUBSCRIPTION_EVENT", "SUMMARY") {
            result.events = SalesReportParser.events(table, fallbackDay: job.day)
        }
        if let table = try await report("SUBSCRIBER", "DETAILED") {
            result.subscribers = SalesReportParser.subscribers(table, fallbackDay: job.day)
        }
        return result
    }
}
