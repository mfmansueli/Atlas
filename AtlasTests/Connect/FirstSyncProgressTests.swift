//
//  FirstSyncProgressTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("FirstSyncProgress")
struct FirstSyncProgressTests {
    @Test func readsTheTeamFirst() {
        let progress = FirstSyncProgress()
        #expect(progress.fraction == 0)
        #expect(progress.detail == "Reading your team and apps…")
        #expect(progress.summary == "Reading your team and its apps. Nothing is changed in App Store Connect.")
    }

    @Test func countsAppsAsTheirSummariesLoad() {
        let progress = FirstSyncProgress(
            appCount: 6, syncedCount: 3, teamName: "Northpier Studio", syncedNames: ["Lumen Journal", "Habitat", "Tempo"]
        )
        #expect(progress.detail == "3 of 6 · Lumen Journal, Habitat, Tempo")
        #expect(progress.fraction == 4.0 / 7.0)
        #expect(progress.summary == """
        Found 6 apps in Northpier Studio. Reading their store pages, screenshots and prices. \
        Nothing is changed in App Store Connect.
        """)
    }

    @Test func listsThreeNamesThenHowManyMore() {
        let progress = FirstSyncProgress(appCount: 9, syncedCount: 5, syncedNames: ["A", "B", "C", "D", "E"])
        #expect(progress.detail == "5 of 9 · A, B, C + 2 more")
    }

    @Test func withoutNamesItCountsOnly() {
        #expect(FirstSyncProgress(appCount: 6, syncedCount: 0).detail == "0 of 6")
    }

    @Test func withoutTheTeamNameItSaysHowManyApps() {
        #expect(FirstSyncProgress(appCount: 6).summary.hasPrefix("Found 6 apps. Atlas is reading their"))
        #expect(FirstSyncProgress(appCount: 1, teamName: "Alba").summary.hasPrefix("Found 1 app in Alba. Atlas is reading its store page"))
    }

    @Test func finishedSyncIsFull() {
        #expect(FirstSyncProgress(appCount: 6, syncedCount: 6).fraction == 1)
        #expect(FirstSyncProgress(appCount: 6, syncedCount: 6).detail == "6 of 6")
    }

    @Test func anEmptyAccountIsDoneAtOnce() {
        #expect(FirstSyncProgress(appCount: 0).fraction == 1)
    }
}
