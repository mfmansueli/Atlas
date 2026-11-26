//
//  AnalyticsOriginTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 92: a finding opens the section where the change is made, which
/// says where the person came from, and Back to Analytics returns to the
/// same view.
@MainActor
@Suite("Analytics · From Analytics and back")
struct AnalyticsOriginTests {
    private let origin = AnalyticsOrigin(appID: "app", text: "Germany downloads half as much as the U.S.", tab: .whatToTry)

    @Test func aStorePageFindingOpensTheLanguageUnderTheBar() throws {
        let navigator = WorkspaceNavigator(section: .analytics)
        navigator.follow(.storePage(locale: "de-DE"), origin: origin)
        #expect(navigator.section == .storePage)
        #expect(navigator.intent == .showLanguage("de-DE"))
        let shown = try #require(navigator.analyticsOrigin)
        #expect(shown.text == origin.text)
        #expect(shown.tab == .whatToTry)
        #expect(shown.section == .storePage)
        #expect(shown.isShown(in: .storePage, of: "app"))
        #expect(!shown.isShown(in: .reviews, of: "app"), "only where the finding led")
        #expect(!shown.isShown(in: .storePage, of: "another"))
        #expect(!shown.isShown(in: .analytics, of: "app"))
    }

    @Test func backToAnalyticsReturnsToTheSameView() {
        let navigator = WorkspaceNavigator(section: .analytics)
        var fromBreakdown = origin
        fromBreakdown.tab = .breakDown
        navigator.follow(.pricing(territory: "BR"), origin: fromBreakdown)
        #expect(navigator.section == .subscriptionPricing)
        #expect(navigator.intent == .showTerritoryPrice("BR"))
        navigator.backToAnalytics()
        #expect(navigator.section == .analytics)
        #expect(navigator.requestedAnalyticsTab == .breakDown)
        #expect(navigator.analyticsOrigin == nil)
        // Nothing to go back to: nothing happens.
        navigator.open(.reviews)
        navigator.backToAnalytics()
        #expect(navigator.section == .reviews)
    }

    @Test func aPriceChangeOpensPricingResults() {
        let navigator = WorkspaceNavigator(section: .analytics)
        var fromChanges = origin
        fromChanges.tab = .afterChanges
        navigator.follow(.pricingResults, origin: fromChanges)
        #expect(navigator.section == .subscriptionPricing)
        #expect(navigator.intent == .showResults)
        #expect(navigator.analyticsOrigin?.section == .subscriptionPricing)
        navigator.backToAnalytics()
        #expect(navigator.requestedAnalyticsTab == .afterChanges)
    }

    @Test func eachActionOpensItsSection() {
        let cases: [(FindingAction, AppWorkspaceSection, WorkspaceIntent?)] = [
            (.storePage(locale: nil), .storePage, nil),
            (.screenshots(locale: "en-US"), .screenshots, .showScreenshotsLanguage("en-US", displayType: .iPhone)),
            (.screenshotsOnDevice(.iPad, locale: "en-US"), .screenshots, .showScreenshotsLanguage("en-US", displayType: .iPad)),
            (.pricing(territory: nil), .subscriptionPricing, nil),
            (.pricingResults, .subscriptionPricing, .showResults),
            (.retention, .subscriptionPricing, .showRetention),
            (.offerMessage, .subscriptionPricing, .newRetentionMessage),
            (.retentionLanguages(count: 2), .subscriptionPricing, .showRetention),
            (.inAppTexts, .storePage, nil),
            (.productPage(name: "Mood"), .productPages, .showProductPage(name: "Mood")),
            (.pageScreenshots(name: "Mood"), .productPages, .makePageScreenshots(name: "Mood")),
        ]
        for (action, section, intent) in cases {
            let navigator = WorkspaceNavigator(section: .analytics)
            navigator.follow(action, origin: origin)
            #expect(navigator.section == section, "\(action)")
            #expect(navigator.intent == intent, "\(action)")
            #expect(action.section == section, "\(action)")
            #expect(navigator.analyticsOrigin?.isShown(in: section, of: "app") == true, "\(action)")
        }
    }

    @Test func actionsInsideAnalyticsSwitchViewWithoutTheBar() {
        for (action, tab) in [(FindingAction.changes, AnalyticsTab.afterChanges), (.stability, .stability), (.billing, .subscriptions)] {
            let navigator = WorkspaceNavigator(section: .analytics)
            navigator.follow(action, origin: origin)
            #expect(navigator.section == .analytics)
            #expect(navigator.requestedAnalyticsTab == tab)
            #expect(navigator.analyticsOrigin == nil)
            #expect(action.section == nil)
        }
    }

    @Test func anOriginWithoutASectionShowsAnywhereButAnalytics() {
        #expect(origin.isShown(in: .reviews, of: "app"))
        #expect(!origin.isShown(in: .analytics, of: "app"))
    }
}
