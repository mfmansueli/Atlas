//
//  KeptProductPagesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// What the product page tools read and keep around them: the section's
/// fresh read instead of App Store Connect, the suggestion fields older
/// archives don't have, and the Not offered texts a draft made from a
/// suggestion takes.
@MainActor
@Suite("Product pages for assistants")
struct KeptProductPagesTests {
    typealias PageID = MCPProductPagesFixtures.PageID

    private let lumen = MCPTestFixtures.apps[0]
    private let tempo = MCPTestFixtures.apps[1]

    @Test func toolsReadTheSectionsPagesInsteadOfAppStoreConnect() async throws {
        let base = CountingProductPagesServices(DebugProductPagesData.snapshot)
        var services = WorkspaceServices.debug
        services.productPages = base
        let section = ProductPagesSnapshot(pages: [], defaultPage: DebugProductPagesData.defaultPage)
        let lumenID = lumen.id
        let kept = services.keepingProductPages { $0 == lumenID ? section : nil }

        #expect(try await kept.productPages.pages(for: lumen) == section)
        #expect(base.reads == 0)
        #expect(try await kept.productPages.pages(for: tempo).pages.count == 5)
        #expect(base.reads == 1)

        // The tools see what the section has.
        var workspace = MCPTestFixtures.workspace()
        workspace.services = kept
        let tool = GetProductPagesTool(store: ProductPagesStore(), analytics: AnalyticsStore())
        let outcome = try await tool.call(MCPToolArguments(["appId": "Lumen Journal"]), in: MCPToolContext(workspace: workspace, clientName: "Claude Code"))
        #expect(outcome.result["pageLimit"]?["pages"] == 0)
        #expect(base.reads == 1)
    }

    @Test func cancellingASubmissionGoesToAppStoreConnect() async throws {
        let base = CountingProductPagesServices(DebugProductPagesData.snapshot)
        var services = WorkspaceServices.debug
        services.productPages = base
        let kept = services.keepingProductPages { _ in nil }

        #expect(kept.productPages.canCancelSubmission)
        try await kept.productPages.cancelSubmission(versionID: "v2", of: lumen)
        #expect(base.cancelled == ["v2"])
    }

    @Test func onlyAFreshReadOfTheSectionIsKept() {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let models = WorkspaceSectionModels(maximumAge: 60, now: { now })
        #expect(models.freshProductPages(lumen.id, refreshCount: 0) == nil)

        let kept = models.models(for: lumen.id)
        let model = ProductPagesViewModel(app: lumen, services: DebugProductPagesServices(), store: ProductPagesStore(), queue: ChangeQueue())
        model.load(snapshot: DebugProductPagesData.snapshot)
        kept.productPages = model
        // Read, but the read isn't stamped as done.
        #expect(models.freshProductPages(lumen.id, refreshCount: 0) == nil)

        kept.didLoad(.productPages, refreshCount: 0)
        #expect(models.freshProductPages(lumen.id, refreshCount: 0) == DebugProductPagesData.snapshot)
        // A Refresh or a push since, or an old read, reads again.
        #expect(models.freshProductPages(lumen.id, refreshCount: 1) == nil)
        now += 61
        #expect(models.freshProductPages(lumen.id, refreshCount: 0) == nil)
        #expect(models.freshProductPages(tempo.id, refreshCount: 0) == nil)
    }

    @Test func aDraftMadeFromASuggestionTakesItsNotOfferedTexts() throws {
        let store = ProductPagesStore()
        let appID = lumen.id
        var suggestion = try #require(DebugProductPagesData.pageSuggestions.first)
        let refused = DebugProductPagesData.refusedSuggestion
        var notOffered = refused
        notOffered.pageID = suggestion.id
        suggestion.notOfferedTexts = [notOffered]
        store.add(suggestion, for: appID)
        let before = store.count(for: appID)

        let draft = ProductPageDraft(
            id: ProductPageDraft.newID(), name: suggestion.name, start: .defaultPage, locales: ["en-US"], suggestionID: suggestion.id
        )
        store.save(draft, for: appID)
        let taken = store.textSuggestions(for: appID, pageID: draft.id)
        #expect(taken.map(\.locale) == ["en-US"])
        #expect(taken.first?.isRefused == true)
        #expect(taken.first?.text == refused.text)
        // Not offered texts aren't counted.
        #expect(store.count(for: appID) == before)

        // Saving the draft again (an edit) doesn't add them twice; a draft
        // made by hand takes none.
        store.save(draft, for: appID)
        #expect(store.textSuggestions(for: appID, pageID: draft.id).count == 1)
        let byHand = ProductPageDraft(id: ProductPageDraft.newID(), name: "By hand", start: .empty, locales: ["en-US"])
        store.save(byHand, for: appID)
        #expect(store.textSuggestions(for: appID, pageID: byHand.id).isEmpty)
    }

    /// Archives written before `start`, `notOfferedTexts` and `evidence`
    /// still read.
    @Test func suggestionsKeptBeforeTheNewFieldsStillRead() throws {
        // As they were kept before the new fields existed.
        var suggestion = try #require(DebugProductPagesData.pageSuggestions.first)
        suggestion.start = nil
        suggestion.notOfferedTexts = nil
        var text = try #require(DebugProductPagesData.textSuggestions.first)
        text.evidence = nil
        let archive = ProductPagesArchive(pageSuggestions: [suggestion], textSuggestions: [text])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(archive)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("notOfferedTexts"))
        #expect(!json.contains("\"start\""))
        #expect(!json.contains("\"evidence\":null"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let read = try decoder.decode(ProductPagesArchive.self, from: Data(json.utf8))
        #expect(read.pageSuggestions.first?.start == nil)
        #expect(read.pageSuggestions.first?.notOfferedTexts == nil)
        #expect(read.textSuggestions.first?.evidence == nil)
        #expect(read.pageSuggestions.first?.name == suggestion.name)
    }
}
#endif
