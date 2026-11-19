//
//  AppStoreConnectQuotaTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("AppStoreConnectQuota")
struct AppStoreConnectQuotaTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func keepsTheLastReadingPerKey() {
        let quota = AppStoreConnectQuota()
        quota.record(header: "user-hour-lim:3600;user-hour-rem:3000;", keyID: "A", at: start)
        quota.record(header: "user-hour-lim:3600;user-hour-rem:2990;", keyID: "A", at: start + 1)
        quota.record(header: "user-hour-lim:3600;user-hour-rem:100;", keyID: "B", at: start)
        #expect(quota.rateLimit(keyID: "A", now: start + 2) == AppStoreConnectRateLimit(limit: 3600, remaining: 2990))
        #expect(quota.rateLimit(keyID: "B", now: start + 2)?.remaining == 100)
    }

    @Test func aKeyWithoutReadingsIsUnknown() {
        #expect(AppStoreConnectQuota().rateLimit(keyID: "A", now: start) == nil)
    }

    @Test func aMissingOrMalformedHeaderKeepsTheLastReading() {
        let quota = AppStoreConnectQuota()
        quota.record(header: "user-hour-lim:3600;user-hour-rem:3000;", keyID: "A", at: start)
        quota.record(header: nil, keyID: "A", at: start + 1)
        quota.record(header: "garbage", keyID: "A", at: start + 2)
        #expect(quota.rateLimit(keyID: "A", now: start + 3)?.remaining == 3000)
    }

    @Test func aReadingOverAnHourOldSaysNothing() {
        let quota = AppStoreConnectQuota()
        quota.record(header: "user-hour-lim:3600;user-hour-rem:10;", keyID: "A", at: start)
        #expect(quota.rateLimit(keyID: "A", now: start + 59 * 60) != nil)
        #expect(quota.rateLimit(keyID: "A", now: start + 60 * 60) == nil)
    }

    @Test func everyReadNotesTheQuotaApplesHeaderGives() async throws {
        let quota = AppStoreConnectQuota()
        let transport = FakeHTTPTransport([
            CannedHTTPResponse(body: #"{"data":[]}"#, headers: ["X-Rate-Limit": "user-hour-lim:3600;user-hour-rem:3143;"]),
        ])
        var client = AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport)
        client.quota = quota
        _ = try await client.apps()
        #expect(quota.rateLimit(keyID: client.credentials.keyID)?.remaining == 3143)
    }

    @Test func aFailedReadNotesTheQuotaToo() async {
        let quota = AppStoreConnectQuota()
        let transport = FakeHTTPTransport([
            CannedHTTPResponse(statusCode: 429, body: "{}", headers: ["X-Rate-Limit": "user-hour-lim:3600;user-hour-rem:0;"]),
        ])
        var client = AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport)
        client.quota = quota
        _ = try? await client.apps()
        #expect(quota.rateLimit(keyID: client.credentials.keyID)?.remaining == 0)
    }
}
