//
//  TemplateRestoreAndKickerToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `propose_template` going back to a version or switching starters, and
/// `propose_captions` with a kicker and locale "all": each waits in the
/// Proposals sheet like any proposal.
@MainActor
@Suite("Template restore, starters and caption kickers over MCP")
struct TemplateRestoreAndKickerToolTests {
    private func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue], document: ScreenshotsDocument = ScreenshotsDebugDocuments.standard
    ) async throws -> (MCPToolOutcome, CenteredScreenshotsServices) {
        let (workspace, services) = MCPScreenshotsFixtures.workspace(document)
        return try await (MCPScreenshotsFixtures.call(tool, arguments, in: workspace), services)
    }

    // MARK: - Template

    @Test func goingBackToAnOlderVersionIsQueuedAsTheOperationsThatMakeIt() async throws {
        let document = ScreenshotsDebugDocuments.standard
        let current = try #require(document.template)
        let history = try #require(document.history)
        let older = try #require(history.versions.first { !TemplateDiff.changes(from: current, to: $0.template).isEmpty })
        let (outcome, services) = try await call(ProposeTemplateTool(), ["restoreVersion": .int(older.number), "reason": "v2 fit German better."])
        #expect(outcome.result["status"] == "queued")
        #expect((outcome.result["changes"]?.intValue ?? 0) > 0)
        var stored = try #require(services.storedDocument)
        let id = try #require(outcome.result["proposalId"]?.stringValue)
        #expect(stored.proposal(id: id)?.title == "Back to template v\(older.number)")
        #expect(stored.history?.currentNumber == history.currentNumber)

        guard case .success = stored.acceptTemplateProposal(id, date: .now, applier: TemplateOperationApplier()) else {
            Issue.record("The restore proposal didn't apply")
            return
        }
        let accepted = try #require(stored.template)
        #expect(TemplateDiff.changes(from: accepted, to: older.template).isEmpty)
    }

    @Test func aWholeTemplateOnAnOlderVersionWaitsForARebase() throws {
        var history = try #require(ScreenshotsDebugDocuments.standard.history)
        let template = try #require(history.currentTemplate)
        let stale = history.acceptWhole(template, basedOn: history.currentNumber - 1, from: "Claude Code", reason: "Old.", date: .now)
        guard case .failure = stale else {
            Issue.record("A stale whole template was saved")
            return
        }
        let saved = history.acceptWhole(template, basedOn: history.currentNumber, from: "Claude Code", reason: "Back.", date: .now)
        guard case let .success(version) = saved else {
            Issue.record("A current whole template wasn't saved")
            return
        }
        #expect(version.author == .assistant(client: "Claude Code"))
        #expect(history.currentNumber == version.number)
    }

    @Test func goingBackToTheCurrentVersionIsRefused() async throws {
        let current = try #require(ScreenshotsDebugDocuments.standard.history?.currentNumber)
        let (outcome, _) = try await call(ProposeTemplateTool(), ["restoreVersion": .int(current), "reason": "Same."])
        #expect(outcome.result["status"] == "refused")
    }

    @Test func anUnknownVersionOrBothArgumentsThrow() async throws {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeTemplateTool(), ["restoreVersion": 99, "reason": "No such version."])
        }
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeTemplateTool(), ["restoreVersion": 1, "starter": "band", "reason": "Both."])
        }
        await #expect(throws: MCPToolError.self) {
            _ = try await call(ProposeTemplateTool(), ["starter": "confetti", "reason": "Unknown."])
        }
    }

    @Test func anotherStarterIsQueuedKeepingTheCaptions() async throws {
        let document = ScreenshotsDebugDocuments.standard
        let template = try #require(document.template)
        let starter = try #require(TemplateStarter.allCases.first { $0 != template.starter })
        let (outcome, services) = try await call(ProposeTemplateTool(), ["starter": .string(starter.rawValue), "reason": "A band reads better."])
        #expect(outcome.result["status"] == "queued", "\(outcome.result)")
        var stored = try #require(services.storedDocument)
        #expect(stored.captions == document.captions)
        #expect(stored.template == template)

        let id = try #require(outcome.result["proposalId"]?.stringValue)
        guard case .success = stored.acceptTemplateProposal(id, date: .now) else {
            Issue.record("The starter proposal didn't apply")
            return
        }
        #expect(stored.template?.starter == starter)
        #expect(stored.history?.currentNumber == (document.history?.currentNumber ?? 0) + 1)
        #expect(stored.captions == document.captions)
    }

    @Test func getTemplateListsTheStarters() async throws {
        let (outcome, _) = try await call(GetTemplateTool(), [:])
        let starters = try #require(outcome.result["starters"]?.arrayValue)
        #expect(starters.count == TemplateStarter.allCases.count)
        #expect(starters.first?["id"] == .string(TemplateStarter.allCases[0].rawValue))
    }

    // MARK: - Captions

    @Test func localeAllBecomesOneItemPerLanguage() {
        let items: [JSONValue] = [["locale": "all", "slot": 1, "headline": "Write daily"], ["locale": "de-DE", "slot": 2, "headline": "Schreib"]]
        let expanded = ProposeCaptionsTool.expandingAll(items, locales: ["en-US", "fr-FR"])
        #expect(expanded.compactMap { $0["locale"]?.stringValue } == ["en-US", "fr-FR", "de-DE"])
        #expect(expanded.allSatisfy { $0["headline"] != nil })
    }

    @Test func slotZeroIsRefusedWithTheSlotsThereAre() async throws {
        let (outcome, _) = try await call(ProposeCaptionsTool(), [
            "items": [["locale": "en-US", "slot": 0, "headline": "Write daily"]], "reason": "Shorter.",
        ])
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["items"]?.arrayValue?.first?["reason"]?.stringValue?.hasPrefix("The template has slots 1 to") == true)
    }

    @Test func aKickerIsKeptWithTheCaption() async throws {
        let (outcome, services) = try await call(ProposeCaptionsTool(), [
            "items": [["locale": "en-US", "slot": 1, "headline": "Write daily", "kicker": "Journal"]], "reason": "Shorter.",
        ])
        #expect(outcome.result["status"] == "queued")
        let id = try #require(outcome.result["proposalId"]?.stringValue)
        let item = try #require(services.storedDocument?.proposal(id: id)?.captions.first)
        #expect(item.kicker == "Journal")
    }

    @Test func aCaptionWithoutAKickerKeepsTheOneThereIs() {
        let current = ScreenshotCaption(headline: "Old", subhead: "Sub", kicker: "Kick")
        let item = CaptionProposalItem(locale: "en-US", slot: 0, headline: "New")
        let caption = item.caption(over: current, provenance: .reviewed)
        #expect(caption.headline == "New")
        #expect(caption.kicker == "Kick")
        #expect(caption.subhead == "Sub")
        var withKicker = item
        withKicker.kicker = "Fresh"
        #expect(withKicker.caption(over: current, provenance: .reviewed).kicker == "Fresh")
    }
}
