//
//  AddedKeyTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// "Add Another Key…"'s done step and header: the team it added, its
/// apps, and the choice between the team in use and the new one.
@Suite("AddedKey")
struct AddedKeyTests {
    private func added(team: String? = "Fieldworks Studio", count: Int = 3, names: [String]? = ["Trailhead", "Ledgerly", "Kiln"]) -> AddedKey {
        let check = KeyAccessCheck(
            appCount: count, milliseconds: 120, salesAccess: .readable, date: Date(timeIntervalSince1970: 0),
            appNames: names, teamName: team
        )
        return AddedKey(keyID: "7QK2M8ZP1D", check: check, keptTeam: "Northpier Studio")
    }

    @Test func namesTheTeamItAddedAndTheOneThatStays() {
        let key = added()
        #expect(key.title == "Fieldworks Studio is connected")
        #expect(key.message == "Its 3 apps are in the app switcher, under their own team. Atlas stays in Northpier Studio until you switch.")
        #expect(key.keepTitle == "Keep Northpier Studio")
        #expect(key.switchTitle == "Switch to Fieldworks Studio")
        #expect(key.appsLine == "3 of 3 · Trailhead, Ledgerly, Kiln")
    }

    @Test func withoutATeamNameItSaysTheNewKey() {
        let key = added(team: nil)
        #expect(key.title == "The new key is connected")
        #expect(key.switchTitle == "Switch to the New Key")
    }

    @Test func oneAppAndNoAppsReadNaturally() {
        #expect(added(count: 1, names: ["Kiln"]).message.hasPrefix("Its app is in the app switcher, under its own team."))
        #expect(added(count: 0, names: []).message.hasPrefix("It has no apps yet."))
        #expect(added(count: 0, names: []).appsLine == nil)
        #expect(added(names: nil).appsLine == nil, "A check saved before names were kept")
    }

    @Test func longListsEndInMore() {
        let key = added(count: 5, names: ["A", "B", "C", "D", "E"])
        #expect(key.appsLine == "5 of 5 · A, B, C + 2 more")
    }

    @Test func headerNamesTheTeamThatStays() {
        #expect(AddKeyCopy.eyebrow == "Another App Store Connect team")
        #expect(AddKeyCopy.subtitle(keeping: "Northpier Studio")
            == "Same steps as your first setup, for the other team. Northpier Studio stays connected; switch teams in the app switcher.")
    }
}
