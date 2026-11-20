//
//  ProposeProductPageToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_product_page`: a whole page suggested for the person, with
/// evidence Atlas can show, kept on this Mac; what can't be made is refused
/// with how to fix it, and a text App Review would reject is kept as Not
/// offered.
@MainActor
@Suite("propose_product_page")
struct ProposeProductPageToolTests {
    typealias Fixtures = MCPProductPagesFixtures
    typealias PageID = MCPProductPagesFixtures.PageID

    private let fixtures = MCPProductPagesFixtures()
    private let appID = MCPProductPagesFixtures.appID

    private func problems(_ outcome: MCPToolOutcome) -> [String] {
        outcome.result["problems"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    @Test func aPageWithEvidenceIsKeptForThePerson() async throws {
        var arguments = Fixtures.pageArguments(
            texts: ["en-US": "One calm page for your week: your moments, your mood.", "de-DE": "Eine ruhige Seite für deine Woche."],
            keywords: ["en-US": ["Reflection", "reflection"], "de-DE": "reflexion, dankbarkeit"]
        )
        arguments["screens"] = [["screen": "Weekly Reflections", "caption": "Your week on one page"], "Mood"]
        arguments["deepLink"] = "https://lumen.app/week"
        arguments["startFrom"] = "empty"
        let before = fixtures.store.count(for: appID)

        let outcome = try await fixtures.call(fixtures.pageTool, arguments)
        let result = outcome.result
        #expect(result["status"] == "suggested")
        let id = try #require(result["suggestionId"]?.stringValue)
        #expect(id.hasPrefix(ProductPageProposal.idPrefix))
        #expect(result["replaced"] == false)
        #expect(result["languages"] == ["de-DE", "en-US"])
        // The approved version's spelling, once.
        #expect(result["keywords"]?["en-US"] == ["reflection"])
        #expect(result["pageLimit"]?["suggestedPagesWaiting"] == 3)
        #expect(result["pageLimit"]?["roomFor"] == 61)
        #expect(result["languagesWithoutText"]?.arrayValue?.contains("ja") == true)
        #expect(result["languagesWithoutText"]?.arrayValue?.contains("en-US") == false)
        #expect(result["notOffered"] == nil)
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.proposed)

        let suggestion = try #require(fixtures.store.pageSuggestions(for: appID).first { $0.id == id })
        #expect(suggestion.name == "Weekly look back")
        #expect(suggestion.audience.hasPrefix("For people who want a look back"))
        #expect(suggestion.evidence == [SuggestionEvidence(kind: "analytics", ref: "Product Page test")])
        #expect(suggestion.keywords == ["en-US": ["reflection"], "de-DE": ["reflexion", "dankbarkeit"]])
        #expect(suggestion.promotionalTexts["de-DE"] == "Eine ruhige Seite für deine Woche.")
        #expect(suggestion.screens == "Weekly Reflections (“Your week on one page”), then Mood")
        #expect(suggestion.deepLink == "https://lumen.app/week")
        #expect(suggestion.start == .empty)
        #expect(suggestion.source == "Claude Code")
        #expect(suggestion.notOfferedTexts == nil)
        // The section's count: one more suggested page.
        #expect(fixtures.store.count(for: appID) == before + 1)
    }

    @Test func aTextAppReviewWouldRejectIsKeptAsNotOffered() async throws {
        let before = fixtures.store.count(for: appID)
        let outcome = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments(texts: [
            "en-US": "Try Lumen free, now on Android too.", "de-DE": "Eine ruhige Seite für deine Woche.",
        ]))
        let result = outcome.result
        #expect(result["status"] == "suggested")
        let refused = try #require(result["notOffered"]?.arrayValue)
        #expect(refused.compactMap { $0["locale"]?.stringValue } == ["en-US"])
        let kinds = refused.first?["issues"]?.arrayValue?.compactMap { $0["kind"]?.stringValue } ?? []
        #expect(kinds.contains("pricing"))
        #expect(kinds.contains("otherPlatform"))
        #expect(refused.first?["reason"]?.stringValue?.contains("Not offered") == true)
        #expect(result["note"] != nil)
        #expect(result["languages"] == ["de-DE"])
        #expect(result["languagesWithoutText"]?.arrayValue?.contains("en-US") == true)

        let id = try #require(result["suggestionId"]?.stringValue)
        let suggestion = try #require(fixtures.store.pageSuggestions(for: appID).first { $0.id == id })
        // Never offered to accept: it isn't one of the page's texts.
        #expect(suggestion.promotionalTexts["en-US"] == nil)
        let notOffered = try #require(suggestion.notOfferedTexts?.first)
        #expect(notOffered.pageID == id)
        #expect(notOffered.locale == "en-US")
        #expect(notOffered.text == "Try Lumen free, now on Android too.")
        #expect(notOffered.isRefused)
        #expect(notOffered.refusedPhrases.contains("free"))
        #expect(notOffered.refusedPhrases.contains("Android"))
        #expect(fixtures.store.count(for: appID) == before + 1)
    }

    @Test func everyProblemIsRefusedAtOnceWithItsFix() async throws {
        var arguments = Fixtures.pageArguments(
            name: "prompts",
            texts: ["en-US": .string(String(repeating: "a", count: 171)), "xx-XX": "Hi", "fi": "Hei"],
            keywords: ["en-US": ["banana", "mood"]]
        )
        arguments["deepLink"] = "lumen:/lock"
        let outcome = try await fixtures.call(fixtures.pageTool, arguments)
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.isError == false)
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.refused)
        let listed = problems(outcome)
        #expect(listed.contains { $0.contains("“Prompts” is already a page in App Store Connect") })
        #expect(listed.contains { $0.contains("“banana” isn't one of version 1.3's keywords in en-US") })
        #expect(listed.contains { $0.contains("“mood” (en-US) leads to “Mood tracking” already") })
        #expect(listed.contains { $0.contains("has 171 characters; it holds 170") })
        #expect(listed.contains { $0.contains("“xx-XX” isn't an App Store locale code") })
        #expect(listed.contains { $0.contains("“fi” isn't one of Lumen Journal's App Store languages") })
        #expect(listed.contains { $0.contains("isn’t a complete link") })
        #expect(fixtures.store.pageSuggestions(for: appID).map(\.id) == ["weekly", "grat"])
    }

    @Test func aPageWithoutEvidenceAtlasCanShowIsRefused() async throws {
        let none = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments(evidence: []))
        #expect(problems(none).contains { $0.contains("needs evidence Atlas can show") })

        let git = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments(evidence: [["source": "git", "detail": "v1.3..HEAD"]]))
        #expect(problems(git).contains { $0.contains("“git” isn't evidence Atlas can show") })

        let long = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments(evidence: [
            ["source": "reviews", "detail": .string(String(repeating: "x", count: 61))],
        ]))
        #expect(problems(long).contains { $0.contains("holds 60 characters") })

        let noKeywords = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments(keywords: [:], evidence: [["source": "keywords"]]))
        #expect(problems(noKeywords).contains { $0.contains("choose some of the approved version's keywords") })

        var empty = fixtures
        empty.analytics = AnalyticsStore()
        empty.reviews = ReviewsStore()
        let analytics = try await empty.call(empty.pageTool, Fixtures.pageArguments())
        #expect(problems(analytics).contains { $0.contains("no Analytics numbers for Lumen Journal") })
        let reviews = try await empty.call(empty.pageTool, Fixtures.pageArguments(evidence: [["source": "Reviews", "detail": "23 say gratitude"]]))
        #expect(problems(reviews).contains { $0.contains("read them with get_reviews first") })

        // Reviews Atlas read and the approved keywords count.
        let shown = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments(evidence: [
            ["source": "reviews", "detail": "23 say gratitude"], ["source": "keywords", "detail": "of 1.3"],
        ]))
        #expect(shown.result["status"] == "suggested")
        #expect(fixtures.store.pageSuggestions(for: appID).count == 3)
    }

    @Test func theLimitCountsDraftsAndSuggestedPagesWaiting() async throws {
        var full = fixtures
        full.services = DebugProductPagesServices(isAtLimit: true)
        let atLimit = try await full.call(full.pageTool, Fixtures.pageArguments())
        #expect(problems(atLimit).contains { $0.contains("has 70 of 70 pages, the most Apple allows") })

        // 69 pages and two suggested pages waiting would fill the rest.
        full.store.removeDrafts([PageID.privateDiary], for: appID)
        let waiting = try await full.call(full.pageTool, Fixtures.pageArguments())
        #expect(problems(waiting).contains { $0.contains("2 suggested pages waiting") })

        full.store.dismiss("weekly", for: appID)
        full.store.dismiss("grat", for: appID)
        let room = try await full.call(full.pageTool, Fixtures.pageArguments())
        #expect(room.result["status"] == "suggested")
        #expect(room.result["pageLimit"]?["roomFor"] == 0)
    }

    @Test func sendingAPageAgainReplacesItAndADismissedOneStaysDismissed() async throws {
        let first = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments())
        let id = try #require(first.result["suggestionId"]?.stringValue)
        let again = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments(name: "weekly LOOK back", texts: ["en-US": "Your week, on one page."]))
        #expect(again.result["replaced"] == true)
        #expect(again.result["suggestionId"] == .string(id))
        let mine = fixtures.store.pageSuggestions(for: appID).filter { $0.id == id }
        #expect(mine.count == 1)
        #expect(mine.first?.promotionalTexts["en-US"] == "Your week, on one page.")

        let codex = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments(), client: "Codex")
        #expect(problems(codex).contains { $0.contains("Claude Code already suggested a page called “Weekly look back”") })

        fixtures.store.dismiss(id, for: appID)
        let dismissed = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments())
        #expect(problems(dismissed).contains { $0.contains("The person dismissed a suggested page called “Weekly look back”") })
    }

    @Test func keywordsNeedAnApprovedVersion() async throws {
        var fixtures = fixtures
        fixtures.services = DebugProductPagesServices(hasNoApprovedVersion: true)
        let outcome = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments())
        #expect(problems(outcome).contains { $0.contains("No version of Lumen Journal is approved yet, so pages can't choose keywords") })
        // Without keywords it's fine.
        let without = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments(keywords: [:]))
        #expect(without.result["status"] == "suggested")
    }

    @Test func storeTextTurnedOffOrAReadOnlyKeyIsRefused() async throws {
        let off = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments(), allowed: [])
        #expect(off.result["reason"] == .string(MCPProposalKind.storeText.refusal))
        fixtures.store.setKeyCannotChange(true, for: appID)
        let readOnly = try await fixtures.call(fixtures.pageTool, Fixtures.pageArguments())
        #expect(readOnly.result["status"] == "refused")
        #expect(readOnly.result["reason"]?.stringValue?.contains("Admin, App Manager or Marketing") == true)
        #expect(fixtures.store.pageSuggestions(for: appID).count == 2)
    }

    @Test func aPageStartsFromACopyOfAPageInAppStoreConnect() async throws {
        var arguments = Fixtures.pageArguments()
        arguments["startFrom"] = .string(PageID.prompts)
        let outcome = try await fixtures.call(fixtures.pageTool, arguments)
        let id = try #require(outcome.result["suggestionId"]?.stringValue)
        #expect(fixtures.store.pageSuggestions(for: appID).first { $0.id == id }?.start == .copy(pageID: PageID.prompts, name: "Prompts"))

        arguments["startFrom"] = .string(PageID.privateDiary)
        await #expect(throws: MCPToolError.self) {
            try await fixtures.call(fixtures.pageTool, arguments)
        }
    }

    @Test func aCaptionAppReviewWouldRejectIsRefused() async throws {
        var arguments = Fixtures.pageArguments()
        arguments["screens"] = [["screen": "Paywall", "caption": "Free for 7 days"]]
        let outcome = try await fixtures.call(fixtures.pageTool, arguments)
        #expect(problems(outcome).contains { $0.hasPrefix("The caption for Paywall:") })
    }

    @Test func requiredArgumentsAreAskedFor() async throws {
        var arguments = Fixtures.pageArguments()
        arguments.removeValue(forKey: "reason")
        await #expect(throws: MCPToolError.invalidArgument(name: "reason", expected: "a string")) {
            try await fixtures.call(fixtures.pageTool, arguments)
        }
    }
}
#endif
