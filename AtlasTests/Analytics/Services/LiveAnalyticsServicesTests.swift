//
//  LiveAnalyticsServicesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The Analytics Reports API and Sales and Trends, against canned
/// responses: what's asked of Apple, and how its files are read.
@MainActor
@Suite("Analytics · App Store Connect")
struct LiveAnalyticsServicesTests {
    private func services(_ transport: FakeHTTPTransport) -> LiveAnalyticsServices {
        LiveAnalyticsServices(client: AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport))
    }

    private static func requests(_ items: [(String, String, Bool)]) -> CannedHTTPResponse {
        let data = items.map { id, access, stopped in
            #"{"type":"analyticsReportRequests","id":"\#(id)","attributes":{"accessType":"\#(access)","stoppedDueToInactivity":\#(stopped)}}"#
        }
        return CannedHTTPResponse(body: #"{"data":[\#(data.joined(separator: ","))]}"#)
    }

    private static func list(_ type: String, _ items: [(String, String)]) -> CannedHTTPResponse {
        let data = items.map { id, attributes in #"{"type":"\#(type)","id":"\#(id)","attributes":{\#(attributes)}}"# }
        return CannedHTTPResponse(body: #"{"data":[\#(data.joined(separator: ","))]}"#)
    }

    @Test func aStoppedRequestDoesntCountAsOn() async throws {
        let transport = FakeHTTPTransport([Self.requests([("r1", "ONGOING", true), ("r2", "ONE_TIME_SNAPSHOT", false)])])
        let status = try await services(transport).requestStatus(appID: "42")
        #expect(status.requestIDs == ["r2"])
        #expect(!status.isOn)
        #expect(transport.requests.first?.url?.path == "/v1/apps/42/analyticsReportRequests")
    }

    @Test func askingMakesAnOngoingRequestAndASnapshot() async throws {
        let created = CannedHTTPResponse(statusCode: 201, body: #"{"data":{"type":"analyticsReportRequests","id":"new"}}"#)
        let transport = FakeHTTPTransport([Self.requests([]), created, created])
        try await services(transport).askForReports(appID: "42")
        let posts = transport.requests.filter { $0.httpMethod == "POST" }
        #expect(posts.count == 2)
        #expect(posts.allSatisfy { $0.url?.path == "/v1/analyticsReportRequests" })
        let bodies = posts.compactMap { $0.httpBody.flatMap { String(data: $0, encoding: .utf8) } }
        #expect(bodies[0].contains("ONGOING"))
        #expect(bodies[1].contains("ONE_TIME_SNAPSHOT"))
        #expect(bodies[0].contains(#""id":"42""#))
    }

    @Test func askingAgainMakesOnlyWhatIsMissing() async throws {
        let transport = FakeHTTPTransport([Self.requests([("r1", "ONGOING", false), ("r2", "ONE_TIME_SNAPSHOT", false)])])
        try await services(transport).askForReports(appID: "42")
        #expect(transport.requests.count == 1)
    }

    @Test func aKeyThatIsntAdminIsRefused() async {
        let transport = FakeHTTPTransport([Self.requests([]), CannedHTTPResponse(statusCode: 403, body: #"{"errors":[{"detail":"Forbidden"}]}"#)])
        await #expect(throws: AppStoreConnectError.forbidden(detail: "Forbidden")) {
            try await services(transport).askForReports(appID: "42")
        }
    }

    @Test func stoppingDeletesEveryRequest() async throws {
        let done = CannedHTTPResponse(statusCode: 204, body: "")
        let transport = FakeHTTPTransport([Self.requests([("r1", "ONGOING", false), ("r2", "ONE_TIME_SNAPSHOT", false)]), done, done])
        try await services(transport).stopReports(appID: "42")
        let deletes = transport.requests.filter { $0.httpMethod == "DELETE" }.compactMap { $0.url?.path }
        #expect(deletes == ["/v1/analyticsReportRequests/r1", "/v1/analyticsReportRequests/r2"])
    }

    @Test func newInstancesAreDownloadedAndRead() async throws {
        let engagement = """
        Date,App Apple Identifier,Event,Page Type,Source Type,Device,Territory,Counts
        2026-11-09,42,Impression,No page,App Store search,iPhone,US,100
        2026-11-09,42,Page view,Product page,App Store search,iPhone,US,7
        """
        let transport = FakeHTTPTransport([
            Self.requests([("r1", "ONGOING", false)]),
            // Engagement category: one matching report, one that isn't.
            Self.list("analyticsReports", [
                ("rep1", #""name":"App Store Discovery and Engagement Standard","category":"APP_STORE_ENGAGEMENT""#),
                ("rep2", #""name":"App Store Web Preview Engagement Standard","category":"APP_STORE_ENGAGEMENT""#),
            ]),
            Self.list("analyticsReportInstances", [
                ("known", #""granularity":"DAILY","processingDate":"2026-11-10""#), ("new", #""granularity":"DAILY","processingDate":"2026-11-11""#),
            ]),
            // Commerce category: no downloads report yet.
            Self.list("analyticsReports", []),
            Self.list("analyticsReportSegments", [("s1", #""url":"https://files.example.com/0.csv.gz","sizeInBytes":120"#)]),
            CannedHTTPResponse(body: engagement),
        ])
        let batches = try await services(transport).downloadEngagement(appID: "42", known: ["known"])
        #expect(batches.count == 1)
        let batch = try #require(batches.first)
        #expect(batch.instanceID == "new")
        #expect(batch.kind == .engagement)
        #expect(!batch.isDetailed)
        #expect(batch.processing.iso == "2026-11-11")
        #expect(batch.facts.first?.impressions == 100)
        #expect(batch.facts.first?.pageViews == 7)
        let paths = transport.requests.compactMap { $0.url?.path }
        #expect(paths.contains("/v1/analyticsReports/rep1/instances"))
        #expect(!paths.contains("/v1/analyticsReports/rep2/instances"))
        // The signed file URL goes without the API key.
        let file = try #require(transport.requests.last)
        #expect(file.url?.host == "files.example.com")
        #expect(file.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func salesAreReadPerDayAndAMissingDayIsEmpty() async throws {
        let day = try #require(AnalyticsDay(iso: "2026-11-09"))
        let events = "Event Date\tEvent\tApp Apple ID\tSubscription Name\tCountry\tQuantity\n2026-11-09\tSubscribe\t42\tAnnual\tUS\t2\n"
        let transport = FakeHTTPTransport([
            CannedHTTPResponse(body: events),
            CannedHTTPResponse(statusCode: 404, body: #"{"errors":[{"detail":"There were no sales for the date specified."}]}"#),
        ], routes: [(Self.salesProbe, Self.noSales)])
        let download = try await services(transport).downloadSales(vendorNumber: "85012345", days: [day], activeDays: [])
        #expect(download.days == [day])
        #expect(download.events.first?.kind == .paidStart)
        #expect(download.events.first?.quantity == 2)
        #expect(download.subscribers.isEmpty)
        let query = transport.requests.compactMap { $0.url?.query(percentEncoded: false) }.first { $0.contains("SUBSCRIPTION_EVENT") } ?? ""
        #expect(query.contains("filter[vendorNumber]=85012345"))
        #expect(query.contains("filter[reportType]=SUBSCRIPTION_EVENT"))
        #expect(query.contains("filter[version]=1_3"))
        #expect(query.contains("filter[reportDate]=2026-11-09"))
    }

    // MARK: - A vendor nobody subscribed to yet (Alba, 25 Nov)

    /// The Sales report Atlas checks the vendor number with.
    private static let salesProbe = "reportType]=SALES&"
    private static let noSales = CannedHTTPResponse(statusCode: 404, body: #"{"errors":[{"detail":"There were no sales for the date specified."}]}"#)
    private static let invalidVendor = CannedHTTPResponse(
        statusCode: 400,
        body: #"{"errors":[{"status":"400","code":"PARAMETER_ERROR.INVALID","detail":"Invalid vendor number specified. Try again."}]}"#
    )

    @Test func aVendorNobodySubscribedToReadsEmptyDays() async throws {
        let day = try #require(AnalyticsDay(iso: "2026-11-09"))
        let probe = CannedHTTPResponse(body: "Provider\tUnits\n")
        let transport = FakeHTTPTransport([Self.invalidVendor, Self.invalidVendor], routes: [(Self.salesProbe, probe)])
        let download = try await services(transport).downloadSales(vendorNumber: "93207042", days: [day], activeDays: [])
        #expect(download.days == [day])
        #expect(download.events.isEmpty)
        #expect(download.subscribers.isEmpty)
        #expect(download.failedDays.isEmpty)
        let asked = transport.requests.first?.url?.query(percentEncoded: false) ?? ""
        #expect(asked.contains("filter[reportType]=SALES"))
        #expect(asked.contains("filter[reportDate]=2026-11-08"))
    }

    @Test func aWrongVendorNumberIsNamed() async throws {
        let day = try #require(AnalyticsDay(iso: "2026-11-09"))
        let transport = FakeHTTPTransport([], routes: [(Self.salesProbe, Self.invalidVendor)])
        await #expect(throws: SalesVendorNumberError(vendorNumber: "12345678")) {
            _ = try await services(transport).downloadSales(vendorNumber: "12345678", days: [day], activeDays: [])
        }
    }

    @Test func aDayThatFailsKeepsTheOthers() async throws {
        let good = try #require(AnalyticsDay(iso: "2026-11-10"))
        let bad = try #require(AnalyticsDay(iso: "2026-11-05"))
        let refused = CannedHTTPResponse(statusCode: 400, body: #"{"errors":[{"code":"PARAMETER_ERROR.INVALID","detail":"Unexpected date"}]}"#)
        let transport = FakeHTTPTransport([], routes: [
            (Self.salesProbe, Self.noSales),
            ("reportDate]=2026-11-05", refused),
            ("reportDate]=2026-11-10", Self.noSales),
        ])
        let download = try await services(transport).downloadSales(vendorNumber: "85012345", days: [good, bad], activeDays: [])
        #expect(download.days == [good])
        #expect(download.failedDays == [bad])
        #expect(download.failure?.details?.contains("Unexpected date") == true)
    }

    @Test func aKeyThatCantReadSalesIsRefused() async throws {
        let day = try #require(AnalyticsDay(iso: "2026-11-09"))
        let transport = FakeHTTPTransport([CannedHTTPResponse(statusCode: 403, body: #"{"errors":[{"detail":"No access"}]}"#)])
        await #expect(throws: AppStoreConnectError.forbidden(detail: "No access")) {
            _ = try await services(transport).downloadSales(vendorNumber: "85012345", days: [day], activeDays: [])
        }
    }
}
