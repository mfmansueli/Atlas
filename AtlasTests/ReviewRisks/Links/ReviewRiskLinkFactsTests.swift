//
//  ReviewRiskLinkFactsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which URLs are opened, once each, and how.
@MainActor
@Suite("Review risks · Link facts")
struct ReviewRiskLinkFactsTests {
    @Test func eachURLIsOpenedOnceMostImportantFirst() {
        let facts = ReviewRiskLinkFacts(
            supportURLs: ["de-DE": "https://lumen.example.com/hilfe", "en-US": "https://lumen.example.com/help"],
            privacyPolicyURLs: ["en-US": "https://lumen.example.com/privacy", "de-DE": "https://lumen.example.com/privacy"],
            marketingURLs: ["en-US": "https://lumen.example.com"],
            termsURLs: ["en-US": ["https://lumen.example.com/terms"]],
            locales: ["de-DE", "en-US"], primaryLocale: "en-US"
        )
        #expect(facts.urlsToProbe == [
            "https://lumen.example.com/privacy", "https://lumen.example.com/help", "https://lumen.example.com/hilfe",
            "https://lumen.example.com/terms", "https://lumen.example.com",
        ])
    }

    @Test func probingOpensEachOnceAndNamesWhatIsntAWebAddress() async {
        let probe = CannedURLProbe(["https://lumen.example.com/help": .httpError(404)])
        let statuses = await ReviewRiskFactsLoader.probe(["https://lumen.example.com/help", "lumen.example.com/privacy", "not a link"], with: probe)
        #expect(statuses["https://lumen.example.com/help"] == .httpError(404))
        #expect(statuses["lumen.example.com/privacy"] == .opens)
        if case .unreachable = statuses["not a link"] {} else { Issue.record("expected unreachable") }
        #expect(Set(probe.openedURLs) == ["https://lumen.example.com/help", "https://lumen.example.com/privacy"])
    }

    @Test func aWebAddressWithoutSchemeOpensAsHTTPS() {
        #expect(ReviewRiskFactsLoader.webURL("lumen.example.com/help")?.absoluteString == "https://lumen.example.com/help")
        #expect(ReviewRiskFactsLoader.webURL("http://lumen.example.com")?.scheme == "http")
        #expect(ReviewRiskFactsLoader.webURL("localhost") == nil)
    }

    @Test func withoutTheStorePageThereAreNoLinkFacts() {
        #expect(ReviewRiskFactsLoader.linkFacts(storePage: nil, privacyURLs: nil) == nil)
    }
}
