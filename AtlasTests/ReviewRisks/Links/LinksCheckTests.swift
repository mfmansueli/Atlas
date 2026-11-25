//
//  LinksCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// 5.1.1(i) and 1.5: the Privacy Policy and Support URLs exist and open.
@Suite("Review risks · Privacy and support links")
struct LinksCheckTests {
    private let check = LinksCheck()
    private static let privacy = "https://lumen.example.com/privacy"
    private static let support = "https://lumen.example.com/help"

    /// English (U.S.) primary and German, each with both URLs unless
    /// changed.
    private func facts(
        privacy: [String: String] = ["en-US": privacy, "de-DE": privacy],
        support: [String: String] = ["en-US": support, "de-DE": support],
        marketing: [String: String] = [:],
        terms: [String: [String]] = [:],
        statuses: [String: ReviewRiskURLStatus] = [:]
    ) -> ReviewRiskFacts {
        var facts = ReviewRiskFacts(appID: "6450000001", appName: "Lumen")
        facts.links = ReviewRiskLinkFacts(
            supportURLs: support, privacyPolicyURLs: privacy, statuses: statuses, marketingURLs: marketing, termsURLs: terms,
            locales: ["en-US", "de-DE"], primaryLocale: "en-US"
        )
        return facts
    }

    private func risk(_ outcome: ReviewRiskOutcome, _ id: String) -> ReviewRisk? {
        guard case let .risks(risks) = outcome else { return nil }
        return risks.first { $0.id == id }
    }

    private func ids(_ outcome: ReviewRiskOutcome) -> [String] {
        guard case let .risks(risks) = outcome else { return [] }
        return risks.map(\.id)
    }

    @Test func unreadLinksSayItCouldntCheck() {
        guard case .notChecked = check.run(ReviewRiskFacts(appID: "1", appName: "Lumen")) else {
            Issue.record("expected notChecked")
            return
        }
    }

    @Test func everythingThereAndOpeningIsClear() {
        #expect(check.run(facts()) == .clear)
    }

    @Test func noPrivacyPolicyAtAllBlocksReview() throws {
        let risk = try #require(risk(check.run(facts(privacy: [:])), "links:privacyPolicy.missing"))
        #expect(risk.level == .blocksReview)
        #expect(risk.howSure == .sure)
        #expect(risk.fix.arguments["field"] == "privacyPolicyUrl")
        #expect(risk.why.count <= 110)
    }

    @Test func noPrivacyPolicyInThePrimaryLanguageBlocksReview() throws {
        let risk = try #require(risk(check.run(facts(privacy: ["de-DE": Self.privacy])), "links:privacyPolicy.primary"))
        #expect(risk.level == .blocksReview)
        #expect(risk.evidence.first?.locale == "en-US")
    }

    /// False positive guard: another language without one, the primary
    /// with one, isn't a risk.
    @Test func anotherLanguageWithoutAPrivacyPolicyIsNoRisk() {
        #expect(check.run(facts(privacy: ["en-US": Self.privacy])) == .clear)
    }

    @Test func aLanguageWithoutASupportURLBlocksReview() throws {
        let risk = try #require(risk(check.run(facts(support: ["en-US": Self.support])), "links:supportURL.missing"))
        #expect(risk.level == .blocksReview)
        #expect(risk.guideline == "1.5")
        #expect(risk.evidence.map(\.locale) == ["de-DE"])
        #expect(risk.fix.arguments == ["field": "supportUrl", "locales": "de-DE"])
    }

    /// The URL waiting in Review & Push fills the gap.
    @Test func aQueuedSupportURLCounts() {
        var facts = facts(support: ["en-US": Self.support])
        facts.texts = ReviewRiskTextFacts(texts: [ReviewRiskText(
            place: .storeListing, field: .supportURL, label: "Support URL · German", locale: "de-DE", text: Self.support, isQueued: true,
            key: "storeListing.supportUrl.de-DE"
        )])
        #expect(!ids(check.run(facts)).contains("links:supportURL.missing"))
    }

    @Test func aPageNotFoundIsLikelyAndNamesEveryPlace() throws {
        let outcome = check.run(facts(statuses: [Self.support: .httpError(404)]))
        let risk = try #require(risk(outcome, "links:broken.\(Self.support)"))
        #expect(risk.level == .likely)
        #expect(risk.howSure == .sure)
        #expect(risk.title.contains("Support URL"))
        #expect(risk.evidence.count == 2)
        #expect(risk.evidence.allSatisfy { $0.excerpt == Self.support })
        #expect(risk.fix.arguments["locales"] == "en-US,de-DE")
    }

    @Test func aServerErrorOrARefusalIsOnlyWorthALook() {
        let outcome = check.run(facts(statuses: [Self.support: .httpError(503), Self.privacy: .httpError(403)]))
        #expect(risk(outcome, "links:broken.\(Self.support)")?.level == .check)
        #expect(risk(outcome, "links:broken.\(Self.privacy)")?.level == .check)
        #expect(risk(outcome, "links:broken.\(Self.privacy)")?.howSure == .notVerySure)
    }

    @Test func noAnswerIsLikely() {
        let outcome = check.run(facts(statuses: [Self.privacy: .unreachable("timed out")]))
        #expect(risk(outcome, "links:broken.\(Self.privacy)")?.level == .likely)
    }

    @Test func aBrokenMarketingURLIsOnlyWorthALook() {
        let marketing = "https://lumen.example.com/old"
        let outcome = check.run(facts(marketing: ["en-US": marketing], statuses: [marketing: .httpError(404)]))
        #expect(risk(outcome, "links:broken.\(marketing)")?.level == .check)
    }

    @Test func aBrokenTermsLinkPointsTheFixAtTheDescription() throws {
        let terms = "https://lumen.example.com/terms"
        let outcome = check.run(facts(terms: ["en-US": [terms]], statuses: [terms: .httpError(410)]))
        let risk = try #require(risk(outcome, "links:broken.\(terms)"))
        #expect(risk.level == .likely)
        #expect(risk.fix.arguments["field"] == "description")
    }

    @Test func plainHTTPIsWorthALook() throws {
        let http = "http://lumen.example.com/help"
        let risk = try #require(risk(check.run(facts(support: ["en-US": http, "de-DE": http])), "links:insecure.\(http)"))
        #expect(risk.level == .check)
        #expect(risk.evidence.count == 2)
    }

    @Test func idsStayTheSameAcrossRuns() {
        let first = ids(check.run(facts(statuses: [Self.support: .httpError(404)])))
        let second = ids(check.run(facts(statuses: [Self.support: .httpError(410)])))
        #expect(first == second)
    }
}
