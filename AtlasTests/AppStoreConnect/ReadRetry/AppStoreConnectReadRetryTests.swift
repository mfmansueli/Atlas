//
//  AppStoreConnectReadRetryTests.swift
//  AtlasTests
//

import Foundation
import Synchronization
import Testing
@testable import Atlas

/// Pricing's reads asked again after Apple's server failed. On Atlas's own
/// app (2026-11-22), the first read after pushing two new subscriptions
/// waited 12 s for 500 `UNEXPECTED_ERROR`; the same read a moment later
/// answered in 0.3 s.
@Suite("AppStoreConnectReadRetry")
struct AppStoreConnectReadRetryTests {
    private static let serverFailure = AppStoreConnectError.server(
        statusCode: 500, code: "UNEXPECTED_ERROR", detail: "An unexpected error occurred on the server side."
    )
    private static let failureBody = #"""
    {"errors":[{"status":"500","code":"UNEXPECTED_ERROR","title":"An unexpected error occurred.","detail":"An unexpected error occurred on the server side."}]}
    """#

    /// Counts tries and records the pauses taken.
    private final class Log: Sendable {
        private let state = Mutex<(tries: Int, pauses: [Duration])>((0, []))
        var tries: Int { state.withLock { $0.tries } }
        var pauses: [Duration] { state.withLock { $0.pauses } }
        func tried() -> Int { state.withLock { $0.tries += 1; return $0.tries } }
        func paused(_ pause: Duration) { state.withLock { $0.pauses.append(pause) } }
    }

    private func retry(_ log: Log, pauses: [Duration] = [.seconds(1), .seconds(2)]) -> AppStoreConnectReadRetry {
        AppStoreConnectReadRetry(pauses: pauses) { log.paused($0) }
    }

    @Test func aServerFailureIsAskedAgainAfterAPause() async throws {
        let log = Log()
        let value = try await retry(log).run { () async throws -> String in
            if log.tried() == 1 { throw Self.serverFailure }
            return "prices"
        }
        #expect(value == "prices")
        #expect(log.tries == 2)
        #expect(log.pauses == [.seconds(1)])
    }

    @Test func theLastFailureIsThrownOnceThePausesRunOut() async {
        let log = Log()
        await #expect(throws: Self.serverFailure) {
            try await retry(log).run { () async throws -> String in
                _ = log.tried()
                throw Self.serverFailure
            }
        }
        #expect(log.tries == 3)
        #expect(log.pauses == [.seconds(1), .seconds(2)])
    }

    @Test(arguments: [
        AppStoreConnectError.server(statusCode: 400, code: "PARAMETER_ERROR", detail: nil),
        .notFound(detail: nil),
        .rejected(statusCode: 409, code: "STATE_ERROR", detail: nil),
        .rateLimited,
        .unauthorized,
        .unexpectedPayload,
    ])
    func whatDoesntPassInASecondIsntAskedAgain(_ error: AppStoreConnectError) async {
        let log = Log()
        await #expect(throws: error) {
            try await retry(log).run { () async throws -> Int in
                _ = log.tried()
                throw error
            }
        }
        #expect(log.tries == 1)
        #expect(log.pauses.isEmpty)
    }

    @Test func beingOfflineIsntAskedAgain() async {
        let log = Log()
        await #expect(throws: URLError.self) {
            try await retry(log).run { () async throws -> Int in
                _ = log.tried()
                throw URLError(.notConnectedToInternet)
            }
        }
        #expect(log.tries == 1)
    }

    @Test func neverTriesOnce() async {
        let log = Log()
        await #expect(throws: Self.serverFailure) {
            try await AppStoreConnectReadRetry.never.run { () async throws -> Int in
                _ = log.tried()
                throw Self.serverFailure
            }
        }
        #expect(log.tries == 1)
    }

    // MARK: - Pricing's reads

    private func client(_ transport: FakeHTTPTransport, retry: AppStoreConnectReadRetry = .immediate) -> AppStoreConnectClient {
        var client = AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport)
        client.readRetry = retry
        return client
    }

    @Test func aPricingReadThatFailedOnAppleIsAskedForAgain() async throws {
        let transport = FakeHTTPTransport([
            CannedHTTPResponse(statusCode: 500, body: Self.failureBody),
            CannedHTTPResponse(body: #"{"data":[]}"#),
        ])
        let prices = try await client(transport).subscriptionPrices(subscriptionID: "6838000001")
        #expect(prices.data.isEmpty)
        #expect(transport.requests.count == 2)
        #expect(transport.requests.allSatisfy { $0.url?.path() == "/v1/subscriptions/6838000001/prices" })
    }

    @Test func onlyThePageThatFailedIsAskedForAgain() async throws {
        let next = "https://api.appstoreconnect.apple.com/v1/apps/1/subscriptionGroups?cursor=2"
        let transport = FakeHTTPTransport([
            CannedHTTPResponse(body: #"{"data":[],"links":{"next":"\#(next)"}}"#),
            CannedHTTPResponse(statusCode: 503, body: Self.failureBody),
            CannedHTTPResponse(body: #"{"data":[]}"#),
        ])
        _ = try await client(transport).pricedSubscriptionGroups(appID: "1")
        let urls = transport.requests.compactMap { $0.url?.absoluteString }
        #expect(urls.count == 3)
        #expect(urls[1] == next)
        #expect(urls[2] == next)
    }

    @Test func aPricingReadThatKeepsFailingThrowsApplesError() async {
        let failure = CannedHTTPResponse(statusCode: 500, body: Self.failureBody)
        let transport = FakeHTTPTransport([], routes: [("/prices", failure)])
        await #expect(throws: Self.serverFailure) {
            try await client(transport).subscriptionPrices(subscriptionID: "6838000001")
        }
        #expect(transport.requests.count == AppStoreConnectReadRetry.immediate.pauses.count + 1)
    }

    @Test func aRefusedPricingReadIsntAskedAgain() async {
        let missing = CannedHTTPResponse(statusCode: 404, body: #"{"errors":[{"status":"404","code":"NOT_FOUND","title":"x","detail":"Gone."}]}"#)
        let transport = FakeHTTPTransport([], routes: [("/prices", missing)])
        await #expect(throws: AppStoreConnectError.notFound(detail: "Gone.")) {
            try await client(transport).subscriptionPrices(subscriptionID: "6838000001")
        }
        #expect(transport.requests.count == 1)
    }

    /// A subscription whose base price Apple's server won't send still
    /// lists, with no base price; the others keep theirs.
    @MainActor
    @Test func theCatalogListsASubscriptionWhoseBasePriceFailed() async throws {
        let groups = CannedHTTPResponse(body: #"""
        {"data":[{"type":"subscriptionGroups","id":"g1","attributes":{"referenceName":"Atlas Pro"},
        "relationships":{"subscriptions":{"data":[{"type":"subscriptions","id":"s1"}]}}}],
        "included":[{"type":"subscriptions","id":"s1","attributes":{"name":"Atlas Pro Yearly","productId":"pro.yearly",
        "state":"MISSING_METADATA","subscriptionPeriod":"ONE_YEAR"}}]}
        """#)
        let transport = FakeHTTPTransport([], routes: [
            ("subscriptionGroups", groups),
            ("inAppPurchasesV2", CannedHTTPResponse(body: #"{"data":[]}"#)),
            ("/v1/subscriptions/s1/prices", CannedHTTPResponse(statusCode: 500, body: Self.failureBody)),
        ])
        let services = LivePricingServices(client: client(transport))
        let catalog = try await services.catalog(for: DebugFixtures.lumen)
        let product = try #require(catalog.product(id: "s1"))
        #expect(product.name == "Atlas Pro Yearly")
        #expect(product.basePrice == nil)
    }
}
