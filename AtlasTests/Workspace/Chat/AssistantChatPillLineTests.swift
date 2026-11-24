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
        _ chat: AssistantChat = AssistantChat(), canAsk: Bool = true, steps: [AssistantChatStep] = [],
        push: AssistantChatPillLine.PushProgress? = nil
    ) -> AssistantChatPillLine.Inputs {
        AssistantChatPillLine.Inputs(appName: "Lumen", client: "Claude Code", canAsk: canAsk, chat: chat, steps: steps, push: push)
    }

    private func chat(_ state: AssistantChatTurn.State, unseen: Bool = false) -> AssistantChat {
        var turn = AssistantChatTurn(id: UUID(), text: "Q", askedAt: .now)
        turn.state = state
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
        #expect(line.accessibilityLabel(client: "Claude Code") == "Claude Code, Ask about Lumen…")
    }

    @Test func withoutAnAssistantItOffersConnect() {
        let line = AssistantChatPillLine.make(inputs(canAsk: false))
        #expect(line.text == "No assistant connected")
        #expect(line.action == .connect)
        #expect(line.actionTitle == "Connect…")
    }

    @Test func workingCountsTheStepsWithoutGuessingATotal() {
        let steps = [AssistantChatStep(id: 1, text: "Read apps"), AssistantChatStep(id: 2, text: "Read prices")]
        let line = AssistantChatPillLine.make(inputs(chat(.working), steps: steps))
        #expect(line.lead == .dot(.working))
        #expect(line.text == "Read prices")
        #expect(line.detail == "Step 2")
        #expect(line.progress == nil)
        #expect(AssistantChatPillLine.make(inputs(chat(.working))).text == "Starting Claude Code…")
    }

    @Test func aQuestionIsTheOnlyFilledPurple() {
        let question = AssistantChatQuestion(text: "Every product or subscriptions?", choices: ["A", "B"])
        let line = AssistantChatPillLine.make(inputs(chat(.needsYou(question))))
        #expect(line.tag == .needsYou)
        #expect(line.tagText == "Needs you")
        #expect(line.text == "Every product or subscriptions?")
    }

    @Test func anUnseenAnswerSaysWhatArrived() {
        let suggestions = AssistantChatSuggestions(targets: ["Annual · Brazil"], section: .subscriptionPricing)
        let line = AssistantChatPillLine.make(inputs(chat(.answered(text: "Brazil first. Then India.", suggestions: suggestions), unseen: true)))
        #expect(line.text == "Brazil first.")
        #expect(line.tagText == "1 suggestion")
        let plain = AssistantChatPillLine.make(inputs(chat(.answered(text: "Trials went up 12%", suggestions: nil), unseen: true)))
        #expect(plain.tagText == "Answer")
        // Once seen, the line asks again.
        #expect(AssistantChatPillLine.make(inputs(chat(.answered(text: "x", suggestions: nil)))).text == "Ask about Lumen…")
    }

    @Test func aFailureIsAmberWithTryAgainAndComesFirst() {
        let line = AssistantChatPillLine.make(inputs(chat(.failed(.serverNotConnected)), push: .init(sent: 1, total: 2)))
        #expect(line.lead == .dot(.failure))
        #expect(line.text == "Claude Code stopped")
        #expect(line.action == .tryAgain)
    }

    @Test func aPushIsBlueAndCounted() {
        let line = AssistantChatPillLine.make(inputs(push: .init(sent: 14, total: 23)))
        #expect(line.lead == .dot(.push))
        #expect(line.text == "Pushing 23 changes")
        #expect(line.detail == "14 of 23")
        #expect(line.progress == 14.0 / 23.0)
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
