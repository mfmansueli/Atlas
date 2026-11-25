//
//  InAppEventArtworkAskTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Make the Artwork goes through the toolbar (board 56): the app's request
/// says Working… while Claude Code draws, and ends with the run; Claude
/// Code starts even when another request is running.
@MainActor
@Suite("InAppEventArtworkAsk")
struct InAppEventArtworkAskTests {
    private let app = StoreApp(id: "6450000001", name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")

    private func center() -> AssistantAskCenter {
        let center = AssistantAskCenter()
        center.fly = { _, _, _ in false }
        center.announce = { _ in }
        return center
    }

    private func run(_ id: UUID, phase: ClaudeCodeRun.Phase) -> ClaudeCodeRun {
        var run = ClaudeCodeRun(
            id: id, appID: app.id, appName: app.name, purpose: .eventArtwork(eventID: "e1"), prompt: "", workingDirectory: "/tmp",
            startedAt: .now
        )
        run.phase = phase
        return run
    }

    private func launch(_ center: AssistantAskCenter, runID: UUID?) async -> UUID? {
        let ask = InAppEventArtworkAsk.ask(app: app, eventName: "Winter Reflection 2026", client: "Claude Code")
        return await InAppEventArtworkAsk.launch(
            ask, purpose: .eventArtwork(eventID: "e1"), prompt: "Design it", askCenter: center, reduceMotion: true
        ) { _, _ in runID }
    }

    @Test func theToolbarWorksOnTheEventWhileClaudeDraws() async throws {
        let center = center()
        let id = UUID()
        #expect(await launch(center, runID: id) == id)
        let ask = try #require(center.ask(for: app.id))
        #expect(ask.subject == "In-App Events · Winter Reflection 2026")
        #expect(ask.phase == .working)
        #expect(ask.runID == id)

        center.runEnded(run(id, phase: .finished))
        #expect(center.ask(for: app.id) == nil)
        // The page says the concepts are ready; the toolbar adds nothing.
        #expect(center.finished == nil)
    }

    @Test func aFailedRunSaysWhy() async {
        let center = center()
        let id = UUID()
        _ = await launch(center, runID: id)
        center.runEnded(run(id, phase: .failed(.claudeMissing)))
        #expect(center.finished?.text == "Claude Code stopped before it was done. Autopilot says why.")
    }

    @Test func nothingStartedEndsTheRequest() async {
        let center = center()
        #expect(await launch(center, runID: nil) == nil)
        #expect(center.ask(for: app.id) == nil)
        #expect(center.finished == nil)
    }

    @Test func anotherRequestDoesntStopTheArtwork() async {
        let center = center()
        center.send(AssistantAsk(appID: app.id, client: "Claude Code", subject: "Store Page"), from: nil, reduceMotion: true)
        let id = UUID()
        #expect(await launch(center, runID: id) == id)
        #expect(center.ask(for: app.id)?.subject == "Store Page")
        #expect(center.ask(for: app.id)?.runID == nil)
    }
}
