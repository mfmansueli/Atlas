//
//  AssistantChatPillLineTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Chat · the closed line (board 69)")
struct AssistantChatPillLineTests {
    private func inputs(
        _ chat: AssistantChat = AssistantChat(), canAsk: Bool = true, progress: AssistantChatProgress = AssistantChatProgress(),
        push: AssistantChatPillLine.PushProgress? = nil
    ) -> AssistantChatPillLine.Inputs {
        AssistantChatPillLine.Inputs(appName: "Lumen", client: "Claude Code", canAsk: canAsk, chat: chat, progress: progress, push: push)
    }

    private static let turnID = UUID()
    private static let endedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let steps = [AssistantChatStep(id: 1, text: "Read apps"), AssistantChatStep(id: 2, text: "Read prices")]

    private func chat(_ state: AssistantChatTurn.State, unseen: Bool = false) -> AssistantChat {
        var turn = AssistantChatTurn(id: Self.turnID, text: "Q", askedAt: .now)
        turn.state = state
        if state != .working { turn.endedAt = Self.endedAt }
        var chat = AssistantChat(turns: [turn])
        chat.isUnseen = unseen
        return chat
    }

    @Test func readyAsksAboutTheApp() {
        let line = AssistantChatPillLine.make(inputs())
        #expect(line.lead == .sparkles)
        #expect(line.text == "Ask about Lumen…")
        #expect(line.isPlaceholder)
        #expect(line.showsShortcut)
        #expect(line.accessibilityLabel(client: "Claude Code") == "Claude Code: Ask about Lumen…")
        #expect(line.accessibilityValue.isEmpty)
        #expect(!line.sweeps)
        #expect(line.meter == nil)
    }

    @Test func withoutAnAssistantItOffersConnect() {
        let line = AssistantChatPillLine.make(inputs(canAsk: false))
        #expect(line.text == "No assistant connected")
        #expect(line.action == .connect)
        #expect(line.actionTitle == "Connect…")
    }

    @Test func sendingBreathesAndSweepsWithNothingToCount() {
        let line = AssistantChatPillLine.make(inputs(chat(.working)))
        #expect(line.lead == .breathing)
        #expect(line.text == "Sending to Claude Code…")
        #expect(line.sweeps)
        #expect(line.detail == nil)
        #expect(line.meter == nil)
        #expect(line.tag == nil)
        #expect(line.accessibilityLabel(client: "Claude Code") == "Claude Code: Sending to Claude Code…")
        #expect(line.accessibilityValue.isEmpty)
    }

    @Test func workingCountsTheStepsAndTheAnswerToWrite() {
        let line = AssistantChatPillLine.make(inputs(chat(.working), progress: AssistantChatProgress(steps: steps)))
        #expect(line.lead == .breathing)
        #expect(line.text == "Read prices…")
        #expect(line.sweeps)
        #expect(line.detail == "2 of 3")
        #expect(line.meter == .init(fraction: 1.0 / 3, isAI: true))
        #expect(line.accessibilityLabel(client: "Claude Code") == "Claude Code: Read prices…")
        #expect(line.accessibilityValue == "2 of 3")
    }

    @Test func theLastStepWritesTheAnswer() {
        let line = AssistantChatPillLine.make(inputs(chat(.working), progress: AssistantChatProgress(steps: steps, isWriting: true)))
        #expect(line.lead == .breathing)
        #expect(line.text == "Writing the answer…")
        #expect(line.detail == "3 of 3")
        #expect(line.meter == .init(fraction: 2.0 / 3, isAI: true))
    }

    @Test func aPushOutranksTheAnswerBeingWorkedOn() {
        let line = AssistantChatPillLine.make(inputs(chat(.working), progress: AssistantChatProgress(steps: steps), push: .init(sent: 1, total: 2)))
        #expect(line.lead == .push)
        #expect(!line.sweeps)
        #expect(line.meter?.isAI == false)
    }

    @Test func aQuestionIsTheOnlyFilledPurple() {
        let question = AssistantChatQuestion(text: "Every product or subscriptions?", choices: ["A", "B"])
        let line = AssistantChatPillLine.make(inputs(chat(.needsYou(question))))
        #expect(line.tag == .needsYou)
        #expect(line.tagText == "Needs you")
        #expect(line.text == "Every product or subscriptions?")
        // The ✦ stays still; the pill nudges and its tag ticks in.
        #expect(line.lead == .sparkles)
        #expect(!line.sweeps)
        #expect(line.arrival == .init(key: "chat.pill.\(Self.turnID.uuidString)", arrivedAt: Self.endedAt))
        #expect(line.accessibilityLabel(client: "Claude Code") == "Claude Code: Every product or subscriptions?, Needs you")
    }

    @Test func anUnseenAnswerSaysWhatArrived() {
        let suggestions = AssistantChatSuggestions(targets: ["Annual · Brazil"], section: .subscriptionPricing)
        let line = AssistantChatPillLine.make(inputs(chat(.answered(text: "Brazil first. Then India.", suggestions: suggestions), unseen: true)))
        #expect(line.text == "Brazil first.")
        #expect(line.tagText == "1 suggestion")
        // The ✦ blooms and the tag ticks in, keyed by the turn.
        #expect(line.lead == .arrived)
        #expect(line.arrival == .init(key: "chat.pill.\(Self.turnID.uuidString)", arrivedAt: Self.endedAt))
        let plain = AssistantChatPillLine.make(inputs(chat(.answered(text: "Trials went up 12%", suggestions: nil), unseen: true)))
        #expect(plain.tagText == "Answer")
        // Once seen, the line asks again.
        #expect(AssistantChatPillLine.make(inputs(chat(.answered(text: "x", suggestions: nil)))).text == "Ask about Lumen…")
    }

    @Test func aFailureIsAmberWithTryAgainAndComesFirst() {
        let line = AssistantChatPillLine.make(inputs(chat(.failed(.serverNotConnected)), push: .init(sent: 1, total: 2)))
        #expect(line.lead == .failure)
        #expect(line.text == "Claude Code stopped")
        #expect(line.action == .tryAgain)
        // It slides in once per failure.
        #expect(line.failureKey == "chat.failure.\(Self.turnID.uuidString)")
        #expect(line.arrival == nil)
    }

    @Test func aPushIsBlueAndCounted() {
        let line = AssistantChatPillLine.make(inputs(push: .init(sent: 14, total: 23)))
        #expect(line.lead == .push)
        #expect(line.text == "Pushing 23 changes")
        #expect(line.detail == "14 of 23")
        #expect(line.meter == .init(fraction: 14.0 / 23.0, isAI: false))
        #expect(!line.sweeps)
        #expect(AssistantChatPillLine.make(inputs(push: .init(sent: 0, total: 1))).text == "Pushing 1 change")
    }

    @Test func aDraftIsKept() {
        var drafted = AssistantChat()
        drafted.draft = "Make the Japanese subtitle…\n"
        let line = AssistantChatPillLine.make(inputs(drafted))
        #expect(line.lead == .draft)
        #expect(line.text == "Make the Japanese subtitle…")
    }

    @Test func firstSentence() {
        #expect(AssistantChatPillLine.firstSentence(of: "Yes, as App Enhancements: it helps. More.") == "Yes, as App Enhancements: it helps.")
        #expect(AssistantChatPillLine.firstSentence(of: "No end") == "No end")
    }
}
