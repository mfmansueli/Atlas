//
//  AutopilotBarStripTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which strip the closed Autopilot bar grows above its field (board 80):
/// what needs the person, then what works, what stopped, what's done; and
/// nothing while the bar is open or nothing happens.
@Suite("Autopilot bar · strip")
struct AutopilotBarStripTests {
    private typealias Inputs = AutopilotBarStrip.Inputs

    private static let appID = "1"

    private func make(_ change: (inout Inputs) -> Void = { _ in }) -> AutopilotBarStrip? {
        var inputs = Inputs()
        change(&inputs)
        return AutopilotBarStrip.make(inputs)
    }

    private func chat(_ state: AssistantChatTurn.State, unseen: Bool = false) -> AssistantChat {
        var turn = AssistantChatTurn(id: UUID(), text: "Which countries lose the most sales?", askedAt: .now)
        turn.state = state
        var chat = AssistantChat(turns: [turn])
        chat.isUnseen = unseen
        return chat
    }

    private static let steps = AssistantChatProgress(steps: [AssistantChatStep(id: 0, text: "Read prices")])

    // MARK: - Nothing

    @Test func nothingHappeningShowsNoStrip() {
        #expect(make() == nil)
        #expect(make { $0.state = .autoReplyOn("Auto-reply on") } == nil)
    }

    @Test func openTheConversationTakesItsPlace() {
        #expect(make { $0.isOpen = true; $0.state = .needsYou("Choose the Look") } == nil)
        #expect(make { $0.isOpen = true; $0.chat = chat(.working) } == nil)
    }

    // MARK: - Needs you

    @Test func theAssistantsQuestionShowsItsAnswersAsButtons() throws {
        let question = AssistantChatQuestion(text: "Count every product?", choices: ["Only Subscriptions", "Every Product"])
        let strip = try #require(make { $0.chat = chat(.needsYou(question)) })
        #expect(strip.kind == .needsYou)
        #expect(strip.source == .chat)
        #expect(strip.title == "Count every product?")
        #expect(strip.choices == ["Only Subscriptions", "Every Product"])
        #expect(strip.action == nil)
    }

    @Test func aRunThatWaitsForThePersonOpensWhereItWaits() throws {
        let strip = try #require(make { $0.state = .needsYou("Choose the Look for every device") })
        #expect(strip.kind == .needsYou)
        #expect(strip.source == .run)
        #expect(strip.action == .show)
        #expect(strip.actionTitle == "Show")
    }

    @Test func needingThePersonComesBeforeWhatWorks() {
        let strip = make {
            $0.state = .needsYou("Choose the Look")
            $0.ask = AssistantAsk(appID: Self.appID, client: "Claude Code", subject: "Store Page · German")
        }
        #expect(strip?.kind == .needsYou)
    }

    // MARK: - Working

    @Test func aButtonsRequestSaysItsStepAndQuotesWhatWasSent() throws {
        var ask = AssistantAsk(appID: Self.appID, client: "Claude Code", subject: "Store Page · German")
        ask.runID = UUID()
        let request = AutopilotBarRequest(appID: Self.appID, title: "Suggest Texts", action: .suggestTexts, section: .storePage, sentAt: .now)
        let strip = try #require(make {
            $0.ask = ask
            $0.askProgress = Self.steps
            $0.sent = request
        })
        #expect(strip.kind == .working)
        #expect(strip.source == .ask)
        #expect(strip.title == "Read prices…")
        #expect(strip.detail == "1 of 2")
        #expect(strip.progress != nil)
        #expect(strip.subtitle == "“Suggest Texts · Store Page · German” · they show up in purple")
        #expect(strip.canStop)
    }

    @Test func beforeItsFirstStepARequestHasNoCountAndNoBar() throws {
        let ask = AssistantAsk(appID: Self.appID, client: "Claude Code", subject: "Store Page")
        let strip = try #require(make { $0.ask = ask })
        #expect(strip.title == "Sending to Claude Code…")
        #expect(strip.detail == nil)
        #expect(strip.progress == nil)
        // No run yet: nothing to stop.
        #expect(!strip.canStop)
    }

    @Test func aTypedQuestionWorksWithStop() throws {
        let strip = try #require(make {
            $0.chat = chat(.working)
            $0.chatProgress = Self.steps
        })
        #expect(strip.kind == .working)
        #expect(strip.source == .chat)
        #expect(strip.subtitle == "“Which countries lose the most sales?”")
        #expect(strip.canStop)
    }

    @Test func aCapturingRunCountsAndShowsIt() throws {
        let strip = try #require(make {
            $0.state = .capturing("Capturing Annual · 2 of 3", progress: 1.4)
            $0.canCancelRun = true
        })
        #expect(strip.source == .run)
        #expect(strip.progress == 1)
        #expect(strip.action == .show)
        #expect(strip.canStop)
        #expect(make { $0.state = .capturing("Capturing", progress: 0.5) }?.canStop == false)
    }

    @Test func aGuidedRunDrawsABarOnlyFromCountedUnits() {
        let counted = GuidedRunProgress(title: "Making screenshots", fraction: 0.5, line: "5 of 10 captures", isCounted: true)
        let timed = GuidedRunProgress(title: "Making screenshots", fraction: 0.5, line: "Designing", isCounted: false)
        let running = WorkspaceAutopilotState.running("Making screenshots", isScreenshotRun: true)
        #expect(make { $0.state = running; $0.runProgress = counted }?.progress == 0.5)
        #expect(make { $0.state = running; $0.runProgress = timed }?.progress == nil)
        #expect(make { $0.state = running; $0.runProgress = counted }?.subtitle == "5 of 10 captures")
    }

    @Test func otherWorkHasNoStopAndNoBar() throws {
        let strip = try #require(make { $0.state = .running("Claude Code is working") })
        #expect(strip.source == .assistant)
        #expect(!strip.canStop)
        #expect(strip.progress == nil)
        #expect(strip.action == nil)
    }

    // MARK: - Stopped

    @Test func aStoppedQuestionSaysWhyAndTriesAgain() throws {
        let strip = try #require(make { $0.chat = chat(.failed(.claudeError("Overloaded"))) })
        #expect(strip.kind == .stopped)
        #expect(strip.title == "Claude Code stopped")
        #expect(strip.subtitle?.hasSuffix("Nothing changed in Atlas.") == true)
        #expect(strip.action == .tryAgain)
        #expect(strip.canDismiss)
    }

    @Test func aFailedRunTriesAgainOnlyWhenItsRequestIsKnown() {
        #expect(make { $0.state = .failed("Claude Code stopped with an error") }?.action == .details)
        #expect(make { $0.state = .failed("Claude Code stopped with an error"); $0.canRetryFailure = true }?.action == .tryAgain)
        #expect(make { $0.state = .failed("Claude Code stopped with an error") }?.kind == .stopped)
    }

    // MARK: - Done

    @Test func anUnseenAnswerOpensTheConversation() throws {
        let suggestions = AssistantChatSuggestions(targets: ["Annual · Brazil"], section: .subscriptionPricing)
        let strip = try #require(make { $0.chat = chat(.answered(text: "Brazil, India and Mexico. Most leave.", suggestions: suggestions), unseen: true) })
        #expect(strip.kind == .done)
        #expect(strip.title == "Brazil, India and Mexico.")
        #expect(strip.action == .open)
        #expect(strip.subtitle?.hasSuffix("Open to read the answer") == true)
        // Once seen, nothing.
        #expect(make { $0.chat = chat(.answered(text: "Brazil.", suggestions: nil)) } == nil)
    }

    @Test func aFinishedRequestSaysDoneWithShow() throws {
        let done = AutopilotBarFinished(
            appID: Self.appID, what: "Store Page · German", text: "Its suggestions are marked in purple.", section: .storePage, endedAt: .now
        )
        let strip = try #require(make { $0.done = done })
        #expect(strip.kind == .done)
        #expect(strip.title == "Done · Store Page · German")
        #expect(strip.action == .show)
        #expect(strip.key == done.key)
    }

    @Test func aFinishedRunSaysDone() {
        #expect(make { $0.state = .finished("Done · Screenshots") }?.kind == .done)
    }

    @Test func whatWasClosedStaysClosed() {
        let done = AutopilotBarFinished(appID: Self.appID, what: "Store Page", text: "", section: .storePage, endedAt: .now)
        #expect(make { $0.done = done; $0.dismissed = [done.key] } == nil)
        #expect(make { $0.state = .failed("Stopped"); $0.dismissed = ["failed.Stopped"] } == nil)
    }

    @Test func workingComesBeforeWhatStoppedOrFinished() {
        let done = AutopilotBarFinished(appID: Self.appID, what: "Store Page", text: "", section: .storePage, endedAt: .now)
        #expect(make { $0.done = done; $0.chat = chat(.working) }?.kind == .working)
        #expect(make { $0.state = .failed("Stopped"); $0.chat = chat(.working) }?.kind == .working)
    }

    // MARK: - Words

    @Test func voiceOverSaysAutopilotFirst() {
        #expect(AutopilotBarStrip.announcement("Making screenshots · 5 of 10 captures") == "Autopilot, Making screenshots, 5 of 10 captures")
    }

    @Test func theAnswersFirstSentence() {
        #expect(AutopilotBarStrip.firstSentence(of: "One. Two.") == "One.")
        #expect(AutopilotBarStrip.firstSentence(of: "No end\nSecond line") == "No end")
    }
}
