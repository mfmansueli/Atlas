//
//  AssistantChatCenterTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Chat · the conversation (board 69)")
@MainActor
struct AssistantChatCenterTests {
    private let appID = "6450000001"
    private let context = AssistantChatContext(appID: "6450000001", appName: "Lumen", section: .subscriptionPricing, version: "1.4")
    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// A start that hands out `id` and remembers the prompts and sessions.
    @MainActor
    private final class Starts {
        var prompts: [String] = []
        var sessions: [String?] = []
        var id: UUID? = UUID()

        var start: AssistantChatCenter.StartRun {
            { [self] prompt, session in await run(prompt, session) }
        }

        func run(_ prompt: String, _ session: String?) async -> UUID? {
            prompts.append(prompt)
            sessions.append(session)
            return id
        }
    }

    private func run(_ id: UUID, phase: ClaudeCodeRun.Phase, text: String = "Brazil, India and Mexico.", session: String? = "s1") -> ClaudeCodeRun {
        var run = ClaudeCodeRun(
            id: id, appID: appID, appName: "Lumen", purpose: .chat, prompt: "", workingDirectory: "/tmp", startedAt: start
        )
        run.phase = phase
        run.endedAt = start.addingTimeInterval(30)
        run.sessionID = session
        run.result = ClaudeCodeResult(isError: false, text: text, sessionID: session)
        return run
    }

    @Test func aQuestionWorksThenAnswersWithWhatItSuggested() async throws {
        let center = AssistantChatCenter()
        let starts = Starts()
        let outcome = await center.send("  Which countries lose the most sales? ", context: context, start: starts.start)
        #expect(outcome == .sent)
        let chat = center.chat(for: appID)
        #expect(chat.isWorking)
        #expect(chat.turns.first?.text == "Which countries lose the most sales?")
        #expect(starts.sessions == [nil])
        #expect(starts.prompts.first?.contains("Pricing section of Lumen") == true)
        #expect(starts.prompts.first?.contains("version 1.4") == true)

        let runID = try #require(starts.id)
        let log = [
            MCPLogEntry(
                date: start.addingTimeInterval(10), client: "Claude Code", tool: "propose_prices", target: "Lumen · Annual · Brazil", outcome: .proposed
            ),
            MCPLogEntry(date: start.addingTimeInterval(11), client: "Claude Code", tool: "get_prices", target: "Lumen · Prices", outcome: .read),
            // Before the run: not this answer's.
            MCPLogEntry(
                date: start.addingTimeInterval(-60), client: "Claude Code", tool: "propose_prices", target: "Lumen · Annual · India", outcome: .proposed
            ),
        ]
        center.runEnded(run(runID, phase: .finished), log: log)
        let answered = center.chat(for: appID)
        #expect(!answered.isWorking)
        #expect(answered.sessionID == "s1")
        #expect(answered.isUnseen, "the panel was closed")
        guard case let .answered(text, suggestions) = answered.last?.state else {
            Issue.record("not answered")
            return
        }
        #expect(text == "Brazil, India and Mexico.")
        #expect(suggestions?.targets == ["Annual · Brazil"])
        #expect(suggestions?.section == .subscriptionPricing)
    }

    @Test func aFollowUpResumesTheSession() async throws {
        let center = AssistantChatCenter()
        let starts = Starts()
        await center.send("First", context: context, start: starts.start)
        try center.runEnded(run(#require(starts.id), phase: .finished, session: "abc"), log: [])
        starts.id = UUID()
        await center.send("And India?", context: context, start: starts.start)
        #expect(starts.sessions == [nil, "abc"])
        #expect(starts.prompts.last?.contains("Their next message in the chat: And India?") == true)
    }

    @Test func aQuestionFromTheAssistantWaitsForAQuickReply() async throws {
        let center = AssistantChatCenter()
        let starts = Starts()
        let question = AssistantChatQuestion(text: "Every product or subscriptions?", choices: ["Only Subscriptions", "Every Product"])
        // Nothing works yet: refused.
        #expect(!center.receive(question, for: appID))
        await center.send("Which countries lose the most?", context: context, start: starts.start)
        #expect(center.receive(question, for: appID))
        try center.runEnded(run(#require(starts.id), phase: .finished), log: [])
        #expect(center.chat(for: appID).question == question)

        starts.id = UUID()
        await center.send("Only Subscriptions", context: context, start: starts.start)
        #expect(starts.prompts.last?.contains("You asked: Every product or subscriptions?\nThey answer: Only Subscriptions") == true)
        #expect(center.chat(for: appID).question == nil)
    }

    @Test func anAnswerArrivingWhileOpenIsSeen() async throws {
        let center = AssistantChatCenter()
        center.shownAppID = appID
        center.setOpen(true)
        let starts = Starts()
        await center.send("Hi", context: context, start: starts.start)
        try center.runEnded(run(#require(starts.id), phase: .finished), log: [])
        #expect(!center.chat(for: appID).isUnseen)
    }

    @Test func openingMarksTheShownAppsAnswerSeen() async throws {
        let center = AssistantChatCenter()
        center.shownAppID = appID
        let starts = Starts()
        await center.send("Hi", context: context, start: starts.start)
        try center.runEnded(run(#require(starts.id), phase: .finished), log: [])
        #expect(center.chat(for: appID).isUnseen)
        center.toggle()
        #expect(center.isOpen)
        #expect(!center.chat(for: appID).isUnseen)
    }

    @Test func nothingStartedPutsTheWordsBackAsADraft() async {
        let center = AssistantChatCenter()
        let starts = Starts()
        starts.id = nil
        let outcome = await center.send("Where do people drop off?", context: context, start: starts.start)
        #expect(outcome == .notStarted)
        #expect(center.chat(for: appID).turns.isEmpty)
        #expect(center.chat(for: appID).draft == "Where do people drop off?")
    }

    @Test func emptyAndBusySendsAreRefused() async {
        let center = AssistantChatCenter()
        let starts = Starts()
        #expect(await center.send("   ", context: context, start: starts.start) == .empty)
        #expect(await center.send("One", context: context, start: starts.start) == .sent)
        #expect(await center.send("Two", context: context, start: starts.start) == .busy)
        #expect(starts.prompts.count == 1)
    }

    @Test func aRunThatEndsBeforeItsTurnKnowsItStillEndsIt() async {
        let center = AssistantChatCenter()
        let id = UUID()
        // The launcher ends a run that couldn't start inside `start`.
        await center.send("Hi", context: context) { [self] _, _ in
            center.runEnded(run(id, phase: .failed(.serverNotConnected)), log: [])
            return id
        }
        #expect(center.chat(for: appID).last?.failure == .serverNotConnected)
    }

    @Test func stopAndFailureEndTheTurnAndTryAgainResends() async throws {
        let center = AssistantChatCenter()
        let starts = Starts()
        await center.send("Hi", context: context, start: starts.start)
        #expect(center.workingRunID(for: appID) == starts.id)
        try center.runEnded(run(#require(starts.id), phase: .stopped), log: [])
        #expect(center.chat(for: appID).last?.state == .stopped)
        #expect(center.workingRunID(for: appID) == nil)

        starts.id = UUID()
        await center.send("Again", context: context, start: starts.start)
        try center.runEnded(run(#require(starts.id), phase: .failed(.claudeError("Overloaded"))), log: [])
        #expect(center.chat(for: appID).last?.failure == .claudeError("Overloaded"))

        starts.id = UUID()
        #expect(await center.retry(context: context, start: starts.start) == .sent)
        let chat = center.chat(for: appID)
        #expect(chat.turns.map(\.text) == ["Hi", "Again"])
        #expect(chat.isWorking)
    }

    @Test func otherRunsAreIgnored() {
        let center = AssistantChatCenter()
        var other = run(UUID(), phase: .finished)
        other.purpose = .suggestEverything
        center.runEnded(other, log: [])
        #expect(center.chats.isEmpty)
    }

    @Test func draftsAndRemovedChipsAreKeptPerApp() {
        let center = AssistantChatCenter()
        center.setDraft("Make the subtitle shorter", for: appID)
        center.removeContext(AssistantChatContext.versionChip, for: appID)
        #expect(center.chat(for: appID).hasDraft)
        #expect(center.chat(for: "other").draft.isEmpty)
        #expect(context.chips(removing: center.chat(for: appID).removedContext).map(\.id) == ["app", "section"])
        #expect(context.chips(removing: []).map(\.label) == ["Lumen", "Pricing", "Version 1.4"])
    }
}
