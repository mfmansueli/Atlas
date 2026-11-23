//
//  FirstSyncDoneTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// "Your 6 apps are ready": the first sync's done step before Open Atlas.
@Suite("FirstSyncProgress · done")
struct FirstSyncDoneTests {
    @Test func countsTheAppsAndNamesTheTeam() {
        let progress = FirstSyncProgress(appCount: 6, syncedCount: 6, teamName: "Northpier Studio")
        #expect(progress.doneTitle == "Your 6 apps are ready")
        #expect(progress.doneSummary == "Read every store page, screenshot and price in Northpier Studio. Nothing changed in App Store Connect.")
        #expect(progress.doneDetail == "6 of 6 · read just now")
    }

    @Test func oneAppNoAppsAndNoTeamName() {
        #expect(FirstSyncProgress(appCount: 1, syncedCount: 1).doneTitle == "Your app is ready")
        #expect(FirstSyncProgress(appCount: 0).doneTitle == "Atlas is ready")
        #expect(FirstSyncProgress(appCount: 2, syncedCount: 2).doneSummary
            == "Read every store page, screenshot and price. Nothing changed in App Store Connect.")
    }
}
