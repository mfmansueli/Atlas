//
//  AppSessionAddKeyTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// "Add Another Key…" while a team is connected: the key is saved beside
/// it, with its check and team name, and the key in use stays.
@MainActor
@Suite("AppSession · add another key")
struct AppSessionAddKeyTests {
    private let northpier = TestKeys.credentials(keyID: "2X9R4HXF34", teamName: "Northpier Studio")
    private let fieldworks = TestKeys.credentials(keyID: "7QK2M8ZP1D")
    private let check = KeyAccessCheck(
        appCount: 3, milliseconds: 120, salesAccess: .readable, date: Date(timeIntervalSince1970: 0),
        appNames: ["Trailhead"], teamName: "Fieldworks Studio"
    )

    @Test func savesBesideTheKeyInUseWithoutSwitching() throws {
        let store = FakeCredentialsStore(stored: [northpier])
        let session = AppSession(store: store)
        try session.add(fieldworks, check: check)
        #expect(session.credentials == northpier)
        #expect(session.keys.map(\.keyID) == [northpier.keyID, fieldworks.keyID])
        #expect(session.checks[fieldworks.keyID] == check)
        #expect(session.accounts.last?.name == "Fieldworks Studio")
        #expect(session.firstSyncKeyID == nil, "No first sync until the person switches")
        #expect(try store.loadAll().contains(fieldworks))
    }

    @Test func switchingLaterUsesTheAddedKey() throws {
        let session = AppSession(store: FakeCredentialsStore(stored: [northpier]))
        try session.add(fieldworks, check: check)
        session.select(keyID: fieldworks.keyID)
        #expect(session.credentials == fieldworks)
    }

    @Test func withNoKeyInUseTheAddedKeyIsUsed() throws {
        let session = AppSession(store: FakeCredentialsStore())
        try session.add(fieldworks, check: check)
        #expect(session.credentials == fieldworks)
    }

    @Test func checksSavedBeforeNamesWereKeptStillDecode() throws {
        let old = #"{"appCount":6,"milliseconds":182,"salesAccess":"readable","date":0}"#
        let decoded = try JSONDecoder().decode(KeyAccessCheck.self, from: Data(old.utf8))
        #expect(decoded.appCount == 6)
        #expect(decoded.appNames == nil)
        #expect(decoded.teamName == nil)
    }

    @Test func aKeyThatCantBeSavedChangesNothing() {
        let store = FakeCredentialsStore(stored: [northpier])
        store.saveError = KeychainError(status: errSecDuplicateItem)
        let session = AppSession(store: store)
        #expect(throws: KeychainError.self) { try session.add(fieldworks, check: check) }
        #expect(session.keys == [northpier])
        #expect(session.checks[fieldworks.keyID] == nil)
    }
}
