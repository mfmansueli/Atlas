//
//  WhatsNewCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("What’s New check")
struct WhatsNewCheckTests {
    private typealias Fixture = ReviewRiskTextFixtures

    private func version(_ whatsNew: [String: String], isFirst: Bool = false, isEditable: Bool = true) -> ReviewRiskVersionFacts {
        ReviewRiskVersionFacts(
            versionID: "v1",
            versionString: "1.2.2",
            state: "PREPARE_FOR_SUBMISSION",
            isFirstVersion: isFirst,
            isEditable: isEditable,
            primaryLocale: "en-US",
            whatsNew: whatsNew
        )
    }

    private func risks(_ whatsNew: [String: String], isFirst: Bool = false, isEditable: Bool = true) -> [ReviewRisk] {
        Fixture.risks(WhatsNewCheck().run(Fixture.facts(version: version(whatsNew, isFirst: isFirst, isEditable: isEditable))))
    }

    @Test func anEmptyLanguageBlocksTheUpdate() throws {
        let found = risks(["en-US": "Dark mode for every screen.", "de-DE": "  "])
        let risk = try #require(found.first)
        #expect(found.count == 1)
        #expect(risk.id == "whatsNew:whatsNew.de-DE.empty")
        #expect(risk.level == .blocksReview)
        #expect(risk.howSure == .sure)
        #expect(risk.fix.arguments == ["field": "whatsNew", "locale": "de-DE"])
    }

    @Test func aFirstOrLiveVersionIsntChecked() {
        #expect(risks(["en-US": ""], isFirst: true).isEmpty)
        #expect(risks(["en-US": ""], isEditable: false).isEmpty)
    }

    @Test func anotherVersionNumberIsLikely() throws {
        let risk = try #require(risks(["en-US": "New in Alba 1.2.1: dark mode and a new widget."]).first)
        #expect(risk.id == "whatsNew:whatsNew.en-US.otherVersion")
        #expect(risk.level == .likely)
        #expect(risk.title.contains("1.2.1"))
        #expect(WhatsNewVersionMention.otherVersion(in: "Version 1.2.1 adds widgets", preparing: "1.2.2", appName: "Alba") == "1.2.1")
        #expect(WhatsNewVersionMention.otherVersion(in: "v1.2.1 adds widgets", preparing: "1.2.2", appName: "Alba") == "1.2.1")
        #expect(WhatsNewVersionMention.otherVersion(in: "1.2.1: widgets", preparing: "1.2.2", appName: "Alba") == "1.2.1")
    }

    @Test func otherNumbersArentVersions() {
        #expect(risks(["en-US": "Version 1.2.2 brings dark mode."]).isEmpty)
        #expect(risks(["en-US": "Supports iOS 18.2 and Swift 6.0 widgets, now 2.5 times faster to open."]).isEmpty)
        #expect(WhatsNewVersionMention.otherVersion(in: "Version 1.2.2.0 is here", preparing: "1.2.2", appName: "Alba") == nil)
        #expect(WhatsNewVersionMention.same("1.2", "1.2.1"))
    }

    @Test func genericTextIsWorthALook() throws {
        let risk = try #require(risks(["en-US": "Bug fixes and performance improvements."]).first)
        #expect(risk.id == "whatsNew:whatsNew.en-US.generic")
        #expect(risk.level == .check)
        #expect(risk.howSure == .fairlySure)
        #expect(WhatsNewGenericText.isGeneric("Fehlerbehebungen und Leistungsverbesserungen."))
        #expect(WhatsNewGenericText.isGeneric("Correções de bugs e melhorias de desempenho."))
        #expect(WhatsNewGenericText.isGeneric("バグ修正"))
        #expect(WhatsNewGenericText.isGeneric("Thanks for using Alba! Minor bug fixes.", appName: "Alba"))
    }

    @Test func namedChangesArentGeneric() {
        #expect(!WhatsNewGenericText.isGeneric("Fixed a crash when exporting PDFs."))
        #expect(!WhatsNewGenericText.isGeneric("New features and bug fixes."))
        #expect(risks(["en-US": "Export your journal as PDF, and bug fixes."]).isEmpty)
    }

    @Test func withoutAVersionItSaysWhy() {
        #expect(Fixture.isNotChecked(WhatsNewCheck().run(ReviewRiskFacts(appID: "app1", appName: "Alba"))))
    }
}
