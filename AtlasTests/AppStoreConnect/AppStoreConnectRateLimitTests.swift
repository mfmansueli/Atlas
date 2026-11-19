//
//  AppStoreConnectRateLimitTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("AppStoreConnectRateLimit")
struct AppStoreConnectRateLimitTests {
    @Test func parsesApplesHeader() throws {
        let limit = try #require(AppStoreConnectRateLimit(header: "user-hour-lim:3600;user-hour-rem:3143;"))
        #expect(limit.limit == 3600)
        #expect(limit.used == 457)
        #expect(abs(limit.fractionUsed - 457.0 / 3600.0) < 0.0001)
    }

    @Test(arguments: [nil, "", "user-hour-lim:3600;", "garbage"])
    func missingOrMalformedHeadersAreNil(header: String?) {
        #expect(AppStoreConnectRateLimit(header: header) == nil)
    }

    @Test(arguments: [(3600, true), (901, true), (900, false), (0, false)])
    func readingAheadLeavesTheLastQuarterOfTheHour(remaining: Int, leavesRoom: Bool) {
        #expect(AppStoreConnectRateLimit(limit: 3600, remaining: remaining).leavesRoomToReadAhead == leavesRoom)
    }
}
