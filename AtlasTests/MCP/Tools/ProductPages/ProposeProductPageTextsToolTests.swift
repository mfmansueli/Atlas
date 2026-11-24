//
//  ProposeProductPageTextsToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_product_page_texts`: promotional texts for a page's languages,
/// shown as the usual suggestion block; one App Review would reject is kept
/// as Not offered, and a language that can't take one is skipped with why.
@MainActor
@Suite("propose_product_page_texts")
struct ProposeProductPageTextsToolTests {
    typealias Fixtures = MCPProductPagesFixtures
    typealias PageID = MCPProductPagesFixtures.PageID

    private let fixtures = MCPProductPagesFixtures()
    private let appID = MCPProductPagesFixtures.appID

    private func skipped(_ outcome: MCPToolOutcome) -> [String: String] {
        let items = outcome.result["skipped"]?.arrayValue ?? []
        return Dictionary(items.compactMap { item in
            guard let locale = item["locale"]?.stringValue, let reason = item["reason"]?.stringValue else { return nil }
            return (locale, reason)
        }) { first, _ in first }
    }

    @Test func textsAreSuggestedForADraftAndAnApprovedPage() async throws {
        let before = fixtures.store.count(for: appID)
        let outcome = try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments(PageID.privateDiary, [
            Fixtures.text("fr-FR", "Ton journal, verrouillé avec Face ID.", reason: "Natural French, as the French page."),
            Fixtures.text("de-DE", "Dein Tagebuch, gesperrt mit Face ID."),
        ]))
        #expect(outcome.result["status"] == "suggested")
        #expect(outcome.result["languages"] == ["fr-FR", "de-DE"])
        #expect(outcome.result["skipped"] == [])
        #expect(outcome.result["showsIn"] == "Custom Product Pages (⌘4) → Private diary")
        #expect(outcome.result["newVersionNote"] == nil)
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.proposed)

        let french = try #require(fixtures.store.textSuggestion(for: appID, pageID: PageID.privateDiary, locale: "fr-FR"))
        #expect(french.text == "Ton journal, verrouillé avec Face ID.")
        #expect(french.reason == "Natural French, as the French page.")
        #expect(french.source == "Claude Code")
        #expect(french.evidence == nil)
        #expect(!french.isRefused)
        // Sending a language again replaces its waiting suggestion.
        let german = try #require(fixtures.store.textSuggestion(for: appID, pageID: PageID.privateDiary, locale: "de-DE"))
        #expect(german.text == "Dein Tagebuch, gesperrt mit Face ID.")
        #expect(german.reason == "From the English text.")
        #expect(fixtures.store.count(for: appID) == before + 1)

        // An approved page: it shows once the person presses Edit….
        let approved = try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments(PageID.prompts, [
            Fixtures.text("ja", "毎晩、その日のための新しい問いかけ。"),
        ]))
        #expect(approved.result["languages"] == ["ja"])
        #expect(approved.result["newVersionNote"]?.stringValue?.contains("Edit…") == true)
        #expect(fixtures.store.textSuggestion(for: appID, pageID: PageID.prompts, locale: "ja") != nil)
    }

    @Test func aTextAppReviewWouldRejectIsKeptAsNotOffered() async throws {
        let before = fixtures.store.count(for: appID)
        let outcome = try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments(PageID.privateDiary, [
            Fixtures.text("en-US", "Lumen Plus is 50% off this week."),
        ]))
        #expect(outcome.result["status"] == "suggested")
        #expect(outcome.result["languages"] == [])
        let refused = try #require(outcome.result["notOffered"]?.arrayValue?.first)
        #expect(refused["locale"] == "en-US")
        #expect(refused["issues"]?.arrayValue?.first?["kind"] == "pricing")
        #expect(refused["reason"]?.stringValue?.contains("write another") == true)

        let kept = try #require(fixtures.store.textSuggestion(for: appID, pageID: PageID.privateDiary, locale: "en-US"))
        #expect(kept.isRefused)
        #expect(kept.refusal.contains("App Review rejects this in promotional text"))
        #expect(kept.refusedPhrases.contains("50% off"))
        // Not offered isn't counted: it can't be accepted.
        #expect(fixtures.store.count(for: appID) == before)
    }

    @Test func languagesThatCanNotTakeATextAreSkippedWithWhy() async throws {
        let prompts = try #require(DebugProductPagesData.snapshot.pages.first { $0.id == PageID.prompts })
        let queued = try #require(fixtures.builder.textChange("Ein neuer Impuls jeden Abend.", locale: "de-DE", of: prompts, source: .you))
        fixtures.changes.upsert(queued)
        let outcome = try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments(PageID.prompts, [
            Fixtures.text("xx-XX", "Hi"),
            Fixtures.text("fi", "Hei"),
            Fixtures.text("fr-FR", "  "),
            Fixtures.text("it", String(repeating: "a", count: 171)),
            Fixtures.text("en-US", "A new prompt every evening, written for the day you had. Start with one line."),
            Fixtures.text("de-DE", "Jeden Abend ein neuer Impuls."),
            Fixtures.text("ko", "매일 저녁, 오늘을 위한 새로운 질문."),
            Fixtures.text("ko", "두 번째"),
        ]))
        #expect(outcome.result["languages"] == ["ko"])
        let reasons = skipped(outcome)
        #expect(reasons["xx-XX"]?.contains("isn't an App Store locale code") == true)
        #expect(reasons["fi"]?.contains("isn't one of Lumen Journal's App Store languages") == true)
        #expect(reasons["fr-FR"] == "The text is empty.")
        #expect(reasons["it"]?.contains("has 171 characters") == true)
        #expect(reasons["en-US"]?.contains("the page's text already") == true)
        #expect(reasons["de-DE"]?.contains("waits in Review & Push") == true)
        #expect(reasons["ko"] == "Sent twice: the first is kept.")
        #expect(fixtures.store.textSuggestion(for: appID, pageID: PageID.prompts, locale: "ko")?.text == "매일 저녁, 오늘을 위한 새로운 질문.")
        // Edits queued: an approved page takes texts without Edit….
        #expect(outcome.result["newVersionNote"] == nil)

        let none = try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments(PageID.prompts, [Fixtures.text("xx-XX", "Hi")]))
        #expect(none.result["status"] == "refused")
        #expect(none.result["reason"] == "No language could be kept.")
        #expect(none.result["skipped"]?.arrayValue?.count == 1)
    }

    @Test func aPageInReviewDeletedOrUnknownTakesNoTexts() async throws {
        let german = [Fixtures.text("de-DE", "Jeden Abend ein neuer Impuls.")]
        let inReview = try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments(PageID.sleep, german))
        #expect(inReview.result["status"] == "refused")
        #expect(inReview.result["reason"]?.stringValue?.contains("is with App Review") == true)

        let therapists = try #require(DebugProductPagesData.snapshot.pages.first { $0.id == PageID.therapists })
        fixtures.changes.upsert(fixtures.builder.deleteChange(of: therapists))
        let deleted = try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments(PageID.therapists, german))
        #expect(deleted.result["reason"]?.stringValue?.contains("deleted when the person pushes") == true)

        await #expect(throws: MCPToolError.self) {
            try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments("nope", german))
        }
        let off = try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments(PageID.prompts, german), allowed: [.prices])
        #expect(off.result["reason"] == .string(MCPProposalKind.storeText.refusal))
        fixtures.store.setKeyCannotChange(true, for: appID)
        let readOnly = try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments(PageID.privateDiary, german))
        #expect(readOnly.result["reason"]?.stringValue?.contains("not change them") == true)
    }

    @Test func evidenceIsCheckedAndKeptWhenGiven() async throws {
        let texts = [Fixtures.text("fr-FR", "Ton journal, verrouillé avec Face ID.")]
        let evidence: JSONValue = [["source": "reviews", "detail": "French reviews"]]
        var empty = fixtures
        empty.reviews = ReviewsStore()
        let refused = try await empty.call(empty.textsTool, Fixtures.textsArguments(PageID.privateDiary, texts, evidence: evidence))
        #expect(refused.result["status"] == "refused")
        #expect(refused.result["problems"]?.arrayValue?.first?.stringValue?.contains("get_reviews") == true)

        let kept = try await fixtures.call(fixtures.textsTool, Fixtures.textsArguments(PageID.privateDiary, texts, evidence: evidence))
        #expect(kept.result["status"] == "suggested")
        let suggestion = fixtures.store.textSuggestion(for: appID, pageID: PageID.privateDiary, locale: "fr-FR")
        #expect(suggestion?.evidence == [SuggestionEvidence(kind: "reviews", ref: "French reviews")])

        var arguments = Fixtures.textsArguments(PageID.privateDiary, texts)
        arguments["reason"] = .string(String(repeating: "x", count: 301))
        let long = try await fixtures.call(fixtures.textsTool, arguments)
        #expect(long.result["reason"]?.stringValue?.contains("reason is 301 characters; at most 110") == true)
        arguments.removeValue(forKey: "reason")
        await #expect(throws: MCPToolError.invalidArgument(name: "reason", expected: "a string")) {
            try await fixtures.call(fixtures.textsTool, arguments)
        }
    }
}
#endif
