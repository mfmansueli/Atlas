//
//  StoreTextKeptLinksTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Links a description keeps")
struct StoreTextKeptLinksTests {
    private let current = """
    Plan your week in minutes.

    Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
    Privacy Policy:
    https://lumen.app/p/42
    """

    @Test func linksAreFoundByAddressOrWords() {
        let links = StoreTextKeptLinks.links(in: current)
        #expect(links.map(\.kind) == [.termsOfUse, .privacyPolicy])
        #expect(links.last?.url == "https://lumen.app/p/42")
    }

    @Test func aRewriteThatDropsTheTermsIsRefused() throws {
        let dropped = StoreTextKeptLinks.dropped(from: current, in: "Plan your week in minutes.\nPrivacy Policy: https://lumen.app/p/42")
        #expect(dropped.map(\.kind) == [.termsOfUse])
        let reason = try #require(StoreTextKeptLinks.refusal(dropped))
        #expect(reason.contains("stdeula"))
        #expect(reason.contains("3.1.2(c)"))
    }

    @Test func keepingOrReplacingTheLinkIsFine() {
        let same = "New text.\nhttps://www.apple.com/legal/internet-services/itunes/dev/stdeula\nhttps://lumen.app/p/42"
        #expect(StoreTextKeptLinks.dropped(from: current, in: same).isEmpty)
        let replaced = "New text.\nTerms: https://lumen.app/terms\nPrivacy: https://lumen.app/privacy"
        #expect(StoreTextKeptLinks.dropped(from: current, in: replaced).isEmpty)
    }

    @Test func aDescriptionWithoutLinksKeepsNothing() {
        #expect(StoreTextKeptLinks.dropped(from: "Plan your week. Visit https://lumen.app for tips.", in: "Plan your week.").isEmpty)
        #expect(StoreTextKeptLinks.refusal([]) == nil)
    }
}
