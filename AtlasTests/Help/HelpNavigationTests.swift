//
//  HelpNavigationTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Moving around Atlas Help (board 49): typing searches, Back comes back.
@MainActor
@Suite("Help navigation")
struct HelpNavigationTests {
    @Test func typingSearchesAndClearingGoesHome() {
        let navigation = HelpNavigation()
        navigation.query = "vendor"
        #expect(navigation.place == .search("vendor"))
        navigation.query = " "
        #expect(navigation.place == .home)
    }

    @Test func backReturnsToTheSearchWithItsWords() {
        let navigation = HelpNavigation()
        navigation.query = "vendor"
        navigation.open("analytics")
        #expect(navigation.place == .article("analytics"))
        navigation.open("pricing")
        navigation.back()
        #expect(navigation.place == .article("analytics"))
        navigation.back()
        #expect(navigation.place == .search("vendor"))
        #expect(navigation.query == "vendor")
        #expect(!navigation.canGoBack)
    }

    @Test func openingAnotherPlaceForgetsShowMesNote() {
        let navigation = HelpNavigation()
        navigation.open("connect")
        navigation.shown = "Opened Settings → Accounts in Atlas."
        navigation.goHome()
        #expect(navigation.shown == nil)
        #expect(navigation.query.isEmpty)
        navigation.back()
        #expect(navigation.place == .article("connect"))
    }

    @Test func theSearchHeading() {
        #expect(HelpSearchResultsView.heading(count: 0, query: "x") == "No results for “x”")
        #expect(HelpSearchResultsView.heading(count: 2, query: "vendor") == "2 results for “vendor”")
    }
}
