//
//  UserContentCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("User content safety (1.2)")
struct UserContentCheckTests {
    private typealias Support = ContentRiskTestSupport
    private let check = UserContentCheck()

    private func risks(_ facts: ReviewRiskFacts) -> [ReviewRisk] {
        Support.risks(check.run(facts))
    }

    @Test func userContentWithoutModerationNotes() throws {
        let facts = Support.facts(ageRating: Support.answers([.userGeneratedContent: .affirmative]), reviewNotes: "Demo account below.")
        let notes = try #require(risks(facts).first { $0.id == "userContent:reviewNotes" })
        #expect(notes.level == .likely)
        #expect(notes.fix.tool == "suggest_fields")
        #expect(notes.fix.arguments == ["area": "info", "page": "review", "field": "notes"])
        #expect(notes.evidence.contains { $0.excerpt == "Demo account below." })
    }

    @Test func notesThatExplainReportingAndBlocking() {
        let facts = Support.facts(
            ageRating: Support.answers([.messaging: .affirmative]),
            reviewNotes: "People can report a message and block a user from its menu; we filter words server-side."
        )
        #expect(risks(facts).isEmpty)
    }

    @Test func chatWordsCountWithoutAnAnswer() {
        let facts = Support.facts(texts: [Support.text(.description, "Start a group chat with your team.")])
        #expect(risks(facts).first?.level == .likely)
    }

    @Test func missingSupportURL() throws {
        let facts = Support.facts(
            ageRating: Support.answers([.userGeneratedContent: .affirmative]),
            reviewNotes: "Report and block from any post.",
            links: ReviewRiskLinkFacts(supportURLs: ["en-US": " "])
        )
        let support = try #require(risks(facts).first { $0.id == "userContent:supportURL" })
        #expect(support.level == .likely)
        #expect(support.fix.arguments["field"] == "supportUrl")
        #expect(risks(facts).count == 1)
    }

    @Test func supportURLFromTheStorePageWhenLinksAreMissing() {
        let facts = Support.facts(ageRating: Support.answers([.socialMedia: .affirmative]), reviewNotes: "Moderation: report, block.", supportURL: "")
        #expect(risks(facts).map(\.id) == ["userContent:supportURL"])
    }

    @Test func unknownSupportURLIsNotFlagged() {
        let facts = Support.facts(ageRating: Support.answers([.socialMedia: .affirmative]), reviewNotes: "Moderation: report, block.", supportURL: nil)
        #expect(risks(facts).isEmpty)
    }

    @Test func anAIImageGeneratorIsWorthALook() throws {
        let facts = Support.facts(texts: [Support.text(.subtitle, "AI image generator")])
        let notes = try #require(risks(facts).first)
        #expect(notes.level == .check)
        #expect(notes.howSure == .notVerySure)
    }

    @Test func aiSummariesAreNotUserContent() {
        let facts = Support.facts(texts: [Support.text(.description, "Summaries with AI after every meeting.")])
        #expect(risks(facts).isEmpty)
    }

    @Test func withoutAVersionTheNotesAreLeftAlone() {
        let facts = Support.facts(ageRating: Support.answers([.userGeneratedContent: .affirmative]), hasReviewInformation: false)
        #expect(risks(facts).isEmpty)
    }

    @Test func supportChatAndSharingAreNotUserContent() {
        let facts = Support.facts(texts: [Support.text(.description, "Questions? Chat with our support team. Share your progress with friends.")])
        #expect(risks(facts).isEmpty)
    }

    @Test func aPlainAppHasNothing() {
        #expect(risks(Support.facts(texts: [Support.text(.description, "Count anything with a tap.")])).isEmpty)
    }

    @Test func withoutContentItIsNotChecked() {
        var facts = Support.facts()
        facts.content = nil
        #expect(Support.isNotChecked(check.run(facts)))
    }
}
