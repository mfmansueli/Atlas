//
//  SubscriptionTermsCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// 3.1.2(c): auto-renewable subscriptions need a Privacy Policy URL and a
/// Terms of Use link (or a custom EULA).
@Suite("Review risks · Subscription terms")
struct SubscriptionTermsCheckTests {
    typealias Fixtures = ProductRiskFixtures

    private let check = SubscriptionTermsCheck()
    private let termsID = "subscriptionTerms:termsOfUse"
    private let privacyID = "subscriptionTerms:privacyPolicy"

    @Test func withoutProductsItSaysItCouldntCheck() {
        let facts = ReviewRiskFacts(appID: "1", appName: "Lumen")
        guard case .notChecked = check.run(facts) else {
            Issue.record("expected notChecked")
            return
        }
    }

    @Test func anAppWithoutSubscriptionsHasNothingToFix() {
        let facts = Fixtures.facts([Fixtures.lifetime()], descriptions: ["en-US": Fixtures.noLink], privacy: false)
        #expect(check.run(facts) == .clear)
    }

    @Test func removedSubscriptionsDontCount() {
        let facts = Fixtures.facts([Fixtures.annual(state: "DEVELOPER_REMOVED_FROM_SALE")], descriptions: ["en-US": Fixtures.noLink])
        #expect(check.run(facts) == .clear)
    }

    @Test func noLinkInThePrimaryLanguageBlocksReview() throws {
        let outcome = check.run(Fixtures.facts(descriptions: ["en-US": Fixtures.noLink]))
        let risk = try #require(Fixtures.risk(outcome, termsID))
        #expect(risk.level == .blocksReview)
        #expect(risk.howSure == .sure)
        #expect(risk.guideline == "3.1.2(c)")
        #expect(risk.evidence.map(\.locale) == ["en-US"])
        #expect(risk.fix.tool == "propose_listing_text")
        #expect(risk.fix.arguments["field"] == "description")
        #expect(risk.fix.arguments["locales"] == "en-US")
        #expect(risk.fix.advice.contains(ReviewRiskTermsLink.standardEULA))
        #expect(risk.title.count <= 60)
        #expect(risk.why.count <= 110)
    }

    @Test func onlyAnotherLanguageMissingIsLikely() throws {
        let outcome = check.run(Fixtures.facts(descriptions: ["en-US": Fixtures.terms, "fr-FR": Fixtures.noLink, "de-DE": Fixtures.germanTerms]))
        let risk = try #require(Fixtures.risk(outcome, termsID))
        #expect(risk.level == .likely)
        #expect(risk.evidence.map(\.locale) == ["fr-FR"])
        #expect(risk.fix.arguments["locales"] == "fr-FR")
    }

    @Test func appleStandardEULACountsInEveryLanguage() {
        let standard = "Terms: \(ReviewRiskTermsLink.standardEULA)"
        let outcome = check.run(Fixtures.facts(descriptions: ["en-US": standard, "ja": "利用規約：https://lumen.example.jp/kiyaku"]))
        #expect(Fixtures.ids(outcome).isEmpty)
    }

    @Test func aCustomLicenseAgreementIsEnough() {
        let outcome = check.run(Fixtures.facts(descriptions: ["en-US": Fixtures.noLink], eula: true))
        #expect(Fixtures.ids(outcome).isEmpty)
    }

    @Test func anUnreadLicenseAgreementIsOnlyLikely() throws {
        let outcome = check.run(Fixtures.facts(descriptions: ["en-US": Fixtures.noLink], eula: nil))
        let risk = try #require(Fixtures.risk(outcome, termsID))
        #expect(risk.level == .likely)
        #expect(risk.howSure == .fairlySure)
    }

    /// False positive guard: "subscription terms" just before the privacy
    /// link isn't a Terms of Use link, and the words alone aren't either.
    @Test func aPrivacyLinkOrWordsWithoutALinkDontCount() throws {
        let boilerplate = "Payment renews unless canceled. See the subscription terms in Settings. Privacy Policy: https://lumen.example.com/privacy"
        let outcome = check.run(Fixtures.facts(descriptions: ["en-US": boilerplate, "de-DE": "Es gelten unsere Nutzungsbedingungen."]))
        let risk = try #require(Fixtures.risk(outcome, termsID))
        #expect(Set(risk.evidence.compactMap(\.locale)) == ["en-US", "de-DE"])
    }

    /// The description waiting in Review & Push is what App Review reads.
    @Test func aQueuedDescriptionWithTheLinkClearsIt() {
        var facts = Fixtures.facts(descriptions: ["en-US": Fixtures.noLink])
        facts.texts = ReviewRiskTextFacts(texts: [ReviewRiskText(
            place: .storeListing, field: .description, label: "Description · English (U.S.)", locale: "en-US", text: Fixtures.terms,
            isQueued: true, key: "storeListing.description.en-US"
        )])
        #expect(Fixtures.ids(check.run(facts)).isEmpty)
    }

    @Test func noPrivacyPolicyWithASubscriptionBlocksReview() throws {
        let outcome = check.run(Fixtures.facts(privacy: false))
        let risk = try #require(Fixtures.risk(outcome, privacyID))
        #expect(risk.level == .blocksReview)
        #expect(risk.fix.arguments["field"] == ListingField.privacyPolicyURL.rawValue)
        #expect(Fixtures.risk(outcome, termsID) == nil)
    }

    @Test func unreadLinksDontMakeAPrivacyRisk() {
        var facts = Fixtures.facts()
        facts.links = nil
        #expect(Fixtures.ids(check.run(facts)).isEmpty)
    }

    @Test func theIDStaysTheSameAcrossRuns() {
        let first = Fixtures.ids(check.run(Fixtures.facts(descriptions: ["en-US": Fixtures.noLink])))
        let second = Fixtures.ids(check.run(Fixtures.facts(descriptions: ["en-US": "Other words, still no link."])))
        #expect(first == [termsID])
        #expect(first == second)
    }
}
