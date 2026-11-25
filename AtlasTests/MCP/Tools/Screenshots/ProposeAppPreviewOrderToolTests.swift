//
//  ProposeAppPreviewOrderToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_app_preview_order`: App Previews deleted from a language's
/// set or put in a new order, as its Screenshots page does, waiting in
/// Review & Push.
@MainActor
@Suite("propose_app_preview_order")
struct ProposeAppPreviewOrderToolTests {
    private typealias Content = AppPreviewSetPush.Content

    private static var three: Content {
        Content(
            appID: MCPScreenshotsFixtures.appID, localizationID: "loc-ja", locale: "ja", displayType: .iPhone,
            slots: ["a.mov", "b.mov", "c.mov"].map { AppPreviewSetPush.Slot(liveID: "live-\($0)", fileName: $0) }, deletedIDs: []
        )
    }

    @Test func deletingThenOrderingNamesThePositionsAsTheyWere() throws {
        let edited = try ProposeAppPreviewOrderTool.edit(Self.three, deleting: [2], order: [3, 1]).get()
        #expect(edited.slots.map(\.fileName) == ["c.mov", "a.mov"])
        #expect(edited.deletedIDs == ["live-b.mov"])
    }

    @Test func anOrderMustNameEveryKeptPositionOnce() {
        let missing = ProposeAppPreviewOrderTool.edit(Self.three, deleting: [], order: [2, 1])
        #expect(throws: ProposeAppPreviewOrderTool.Problem.self) { try missing.get() }
        let outside = ProposeAppPreviewOrderTool.edit(Self.three, deleting: [4], order: nil)
        #expect(throws: ProposeAppPreviewOrderTool.Problem.self) { try outside.get() }
    }

    @Test func aDeletionWaitsInReviewAndPush() async throws {
        let (workspace, _) = MCPScreenshotsFixtures.workspace()
        let outcome = try await MCPScreenshotsFixtures.call(ProposeAppPreviewOrderTool(), [
            "locale": "ja", "displayType": "iphone", "delete": [1], "reason": "The preview shows the old search.",
        ], in: workspace)
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["deletedOnPush"] == 1)
        let change = try #require(workspace.changes.change(id: outcome.result["changeId"]?.stringValue ?? ""))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(AppPreviewHandChange.content(of: change)?.slots.isEmpty == true)
        let again = try await MCPScreenshotsFixtures.call(ProposeAppPreviewOrderTool(), [
            "locale": "ja", "displayType": "iphone", "delete": [1], "reason": "Again.",
        ], in: workspace)
        #expect(again.result["status"] == "refused", "The waiting set has none left")
    }

    @Test func theSameOrderAsLiveIsUnchanged() async throws {
        let (workspace, _) = MCPScreenshotsFixtures.workspace()
        let outcome = try await MCPScreenshotsFixtures.call(ProposeAppPreviewOrderTool(), [
            "locale": "ja", "displayType": "iphone", "order": [1], "reason": "Keep it.",
        ], in: workspace)
        #expect(outcome.result["status"] == "unchanged")
    }
}
#endif
