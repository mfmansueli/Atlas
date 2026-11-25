//
//  ProposeProductPageEditToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_product_page_edit` on Lumen Journal's DEBUG pages: a page in
/// App Store Connect changes its name, deep link, keywords or visibility
/// as its editor checks them, or is deleted once the person accepts it.
@MainActor
@Suite("propose_product_page_edit")
struct ProposeProductPageEditToolTests {
    typealias PageID = MCPProductPagesFixtures.PageID

    private let fixtures = MCPProductPagesFixtures()
    private let client = ChangeSource.assistant(client: MCPProductPagesFixtures.client)

    private var tool: ProposeProductPageEditTool {
        ProposeProductPageEditTool(store: fixtures.store, analytics: fixtures.analytics)
    }

    private func edit(_ pageID: String, _ extra: [String: JSONValue]) async throws -> MCPToolOutcome {
        var arguments: [String: JSONValue] = ["appId": "Lumen Journal", "pageId": .string(pageID), "reason": "Gratitude is in 23 reviews."]
        arguments.merge(extra) { _, new in new }
        return try await fixtures.call(tool, arguments)
    }

    private func change(_ pageID: String, _ field: ProductPageField, locale: String? = nil) -> PendingChange? {
        fixtures.changes.change(id: fixtures.builder.changeID(pageID: pageID, field: field, locale: locale))
    }

    @Test func theNewEditToolsAreServed() {
        let names: Set = [
            "propose_product_page_edit", "propose_nomination_delete", "propose_accessibility_draft_deletion", "propose_app_preview_order",
            "propose_price_schedule", "get_queued_changes", "withdraw_changes",
        ]
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: names))
    }

    @Test func aNameAndKeywordsWaitInReviewAndPush() async throws {
        let outcome = try await edit(PageID.year, ["name": "Year in review 2026", "keywords": ["en-US": ["Gratitude", "reflection"]]])
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["changeIds"]?.arrayValue?.count == 2)
        #expect(outcome.logLines.first?.outcome == .proposed)
        let name = try #require(change(PageID.year, .name))
        #expect(name.newValue == "Year in review 2026")
        #expect(name.source == client)
        let keywords = try #require(change(PageID.year, .keywords, locale: "en-US"))
        #expect(keywords.newValue.contains("gratitude"), "The approved version's spelling")
        #expect(keywords.source == client)
    }

    @Test func aKeywordAnotherPageUsesOrOneNotApprovedIsRefused() async throws {
        let taken = try await edit(PageID.year, ["keywords": ["en-US": ["journal"]]])
        #expect(taken.result["status"] == "refused")
        #expect(taken.result["reason"]?.stringValue?.contains("Prompts") == true)
        let unknown = try await edit(PageID.year, ["keywords": ["en-US": ["unicorn"]]])
        #expect(unknown.result["reason"]?.stringValue?.contains("approved version") == true)
        #expect(change(PageID.year, .keywords, locale: "en-US") == nil)
    }

    @Test func aNameAnotherPageHasIsRefused() async throws {
        let outcome = try await edit(PageID.year, ["name": "prompts"])
        #expect(outcome.result["status"] == "refused")
        #expect(change(PageID.year, .name) == nil)
    }

    @Test func anApprovedPagesKeywordsAndDeepLinkWaitForEdit() async throws {
        let outcome = try await edit(PageID.prompts, ["deepLink": "https://lumen.app/prompts/new"])
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("Edit…") == true)
    }

    @Test func aDeepLinkIsCheckedAndQueued() async throws {
        let outcome = try await edit(PageID.year, ["deepLink": "https://lumen.app/year"])
        #expect(outcome.result["status"] == "queued")
        #expect(change(PageID.year, .deepLink)?.newValue == "https://lumen.app/year")
    }

    @Test func onlyAnApprovedPageShowsOrHides() async throws {
        let shown = try await edit(PageID.therapists, ["visible": true])
        #expect(shown.result["status"] == "queued")
        #expect(change(PageID.therapists, .visible)?.source == client)
        let rejected = try await edit(PageID.year, ["visible": true])
        #expect(rejected.result["status"] == "refused")
    }

    @Test func whatThePageHasIsUnchanged() async throws {
        let outcome = try await edit(PageID.therapists, ["name": "Therapists"])
        #expect(outcome.result["status"] == "unchanged")
    }

    @Test func deleteWaitsUntilThePersonAcceptsIt() async throws {
        let outcome = try await edit(PageID.therapists, ["delete": true])
        #expect(outcome.result["status"] == "queued")
        let deletion = try #require(change(PageID.therapists, .delete))
        #expect(deletion.source == client)
        #expect(deletion.awaitingAcceptance != nil)
        #expect(deletion.isBlocked)
    }

    @Test func deleteGoesAloneAndNeverOverThePersonsChanges() async throws {
        let mixed = try await edit(PageID.therapists, ["delete": true, "name": "Old"])
        #expect(mixed.result["status"] == "refused")
        let page = try #require(DebugProductPagesData.pages.first { $0.id == PageID.therapists })
        let theirs = try #require(fixtures.builder.nameChange("For therapists", of: page, source: .you))
        fixtures.changes.upsert(theirs)
        let outcome = try await edit(PageID.therapists, ["delete": true])
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("only the person deletes it") == true)
        #expect(change(PageID.therapists, .delete) == nil)
    }

    @Test func aDraftMadeInAtlasOrAnUnknownPageIsRefused() async throws {
        let draft = try await edit(PageID.privateDiary, ["name": "Locked diary"])
        #expect(draft.result["status"] == "refused")
        await #expect(throws: (any Error).self) { try await edit("no-such-page", ["name": "X"]) }
        await #expect(throws: (any Error).self) { try await edit(PageID.year, [:]) }
    }
}
#endif
