//
//  TeamNamingKeyCheckerTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("TeamNamingKeyChecker")
struct TeamNamingKeyCheckerTests {
    @Test func addsTheTeamNameToAWorkingCheck() async throws {
        let base = FakeKeyChecker()
        let checker = TeamNamingKeyChecker(base: base, lookup: FakeTeamNameLookup(name: "Fieldworks Studio"))
        let check = try await checker.check(TestKeys.credentials())
        #expect(check.teamName == "Fieldworks Studio")
        #expect(check.appCount == base.result.appCount)
    }

    @Test func anUnreadableNameLeavesItNil() async throws {
        let checker = TeamNamingKeyChecker(base: FakeKeyChecker(), lookup: FakeTeamNameLookup(name: nil))
        #expect(try await checker.check(TestKeys.credentials()).teamName == nil)
    }

    @Test func aFailedCheckNeverAsksForTheName() async {
        let base = FakeKeyChecker()
        base.error = AppStoreConnectError.unauthorized
        let lookup = FakeTeamNameLookup(name: "Fieldworks Studio")
        let checker = TeamNamingKeyChecker(base: base, lookup: lookup)
        await #expect(throws: AppStoreConnectError.unauthorized) {
            _ = try await checker.check(TestKeys.credentials())
        }
        #expect(await lookup.asked.count == 0)
    }
}
