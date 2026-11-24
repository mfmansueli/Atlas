//
//  HelpFixLinksTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Help from where people are: the ? beside each section's title opens its
/// article, and Fix a Problem after an error from Apple opens Fix a problem
/// at that kind of error's heading.
@MainActor
@Suite("Help links · ? and Fix a Problem")
struct HelpFixLinksTests {
    private let library = HelpLibrary(bundle: Bundle(for: AppPreferences.self))

    // MARK: - ? beside a section's title

    @Test(arguments: AppWorkspaceSection.allCases)
    func everySectionHasAnArticle(section: AppWorkspaceSection) {
        #expect(library.article(section.helpArticleID) != nil)
    }

    @Test func sectionsOpenTheirOwnArticles() {
        #expect(AppWorkspaceSection.subscriptionPricing.helpArticleID == "pricing")
        #expect(AppWorkspaceSection.screenshots.helpArticleID == "shots")
        #expect(Set(AppWorkspaceSection.allCases.map(\.helpArticleID)).count == AppWorkspaceSection.allCases.count)
    }

    // MARK: - Fix a Problem

    @Test(arguments: HelpFixTopic.allCases)
    func everyTopicIsAHeadingOfFixAProblem(topic: HelpFixTopic) throws {
        let article = try #require(library.article(HelpFixTopic.articleID))
        #expect(article.blocks.contains(.heading(topic.heading)))
    }

    @Test func appleErrorsLandOnTheirHeading() {
        #expect(HelpFixTopic(error: AppStoreConnectError.unauthorized) == .keyRefused)
        #expect(HelpFixTopic.topic(for: .rateLimited) == .hourlyLimit)
        #expect(HelpFixTopic(error: AppStoreConnectError.server(statusCode: 503, detail: nil)) == .appleDown)
        #expect(HelpFixTopic(error: AppStoreConnectError.rejected(statusCode: 409, code: "ENTITY_ERROR", detail: "No.")) == .refused)
        #expect(HelpFixTopic(error: URLError(.notConnectedToInternet)) == .offline)
        #expect(HelpFixTopic(error: URLError(.badServerResponse)) == .appleDown)
    }

    @Test func cancellingAndAtlassOwnErrorsHaveNoHeading() {
        #expect(HelpFixTopic(error: CancellationError()) == nil)
        #expect(HelpFixTopic(error: NSError(domain: "Atlas", code: 1)) == nil)
    }

    @Test func appleErrorCopyCarriesItsHeading() {
        let copy = AppleErrorCopy("Prices didn’t load.", error: URLError(.notConnectedToInternet))
        #expect(copy.fixTopic == .offline)
        #expect(AppleErrorCopy(summary: "Saved.", details: nil).fixTopic == nil)
    }

    @Test func onlyBeingOfflineAlwaysMeansOneHeading() {
        #expect(HelpFixTopic(banner: .offline) == .offline)
        #expect(HelpFixTopic(banner: .apiError) == nil)
        #expect(HelpFixTopic(banner: .rateLimited) == nil)
        #expect(HelpFixTopic(banner: .info) == nil)
    }

    // MARK: - Opening at a heading

    @Test func openingAtAHeadingRemembersIt() {
        let navigation = HelpNavigation()
        navigation.open(.notAllowed)
        #expect(navigation.place == .article("fix"))
        #expect(navigation.heading == "The key can’t do that")
        navigation.open(.offline)
        #expect(navigation.place == .article("fix"))
        #expect(navigation.heading == "Apple can’t be reached")
        #expect(navigation.history == [.home])
    }

    @Test func goingElsewhereForgetsTheHeading() {
        let navigation = HelpNavigation()
        navigation.open(.refused)
        navigation.back()
        #expect(navigation.heading == nil)
        navigation.open(.refused)
        navigation.goHome()
        #expect(navigation.heading == nil)
        navigation.open("pricing")
        #expect(navigation.heading == nil)
    }

    @Test func headingsHaveStableAnchors() {
        #expect(HelpBlock.anchor(for: "Apple didn’t answer") == "heading.Apple didn’t answer")
    }
}
