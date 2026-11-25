//
//  AssistantChatCenter.swift
//  Atlas
//

import Foundation
import Observation

/// The conversation in the Autopilot bar at the bottom of every section
/// (board 80, from board 69's chat): each app's conversation, whether the
/// bar is open, and the Claude Code runs that answer. Each question is one run; a follow-up resumes the
/// session of the one before, so the assistant remembers the chat.
/// Changes come back as suggestions in their sections: the chat never
/// sends anything to Apple.
@MainActor
@Observable
final class AssistantChatCenter {
    static let shared = AssistantChatCenter()

    /// Starts Claude Code with a turn's prompt, resuming a session when it
    /// has one; nil when it couldn't start (no folder chosen).
    typealias StartRun = @MainActor (_ prompt: String, _ resuming: String?) async -> ClaudeCodeRun.ID?

    enum SendOutcome: Equatable {
        case sent
        /// An answer is still coming.
        case busy
        case empty
        /// Nothing started: the draft is back in the field.
        case notStarted
    }

    private(set) var chats: [StoreApp.ID: AssistantChat] = [:]
    /// The Autopilot bar is open (⌘J).
    private(set) var isOpen = false
    /// The app the window shows: what arrives for it while the panel is
    /// open is seen.
    var shownAppID: StoreApp.ID? {
        didSet { markSeenIfOpen() }
    }

    @ObservationIgnored var now: () -> Date = Date.init
    /// What `ask_in_chat` asked during each app's working turn.
    @ObservationIgnored private var questions: [StoreApp.ID: AssistantChatQuestion] = [:]
    /// Runs that ended before their turn knew them: one that couldn't
    /// start ends inside the launcher's `start`.
    @ObservationIgnored private var earlyEnds: [ClaudeCodeRun.ID: (run: ClaudeCodeRun, log: [MCPLogEntry], queued: [PendingChange])] = [:]

    func chat(for appID: StoreApp.ID) -> AssistantChat {
        chats[appID] ?? AssistantChat()
    }

    // MARK: - The panel

    func toggle() { setOpen(!isOpen) }

    func setOpen(_ open: Bool) {
        isOpen = open
        markSeenIfOpen()
    }

    private func markSeenIfOpen() {
        guard isOpen, let shownAppID, chats[shownAppID]?.isUnseen == true else { return }
        chats[shownAppID]?.isUnseen = false
    }

    /// The person closed the bar's “done” strip: the answer counts as seen.
    func markSeen(_ appID: StoreApp.ID) {
        guard chats[appID]?.isUnseen == true else { return }
        chats[appID]?.isUnseen = false
    }

    func setDraft(_ text: String, for appID: StoreApp.ID) {
        guard chat(for: appID).draft != text else { return }
        update(appID) { $0.draft = text }
    }

    /// Takes a context chip out of the app's next questions.
    func removeContext(_ chipID: String, for appID: StoreApp.ID) {
        update(appID) { $0.removedContext.insert(chipID) }
    }

    // MARK: - Asking

    /// Sends `text` as the app's next turn: a question, a follow-up, or the
    /// answer to what the assistant asked.
    @discardableResult
    func send(_ text: String, context: AssistantChatContext, start: StartRun) async -> SendOutcome {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return .empty }
        let appID = context.appID
        let chat = chat(for: appID)
        guard !chat.isWorking else { return .busy }
        let prompt = AssistantChatPrompt.prompt(
            words, context: context, removed: chat.removedContext, isFollowUp: chat.sessionID != nil, answers: chat.question
        )
        let turn = AssistantChatTurn(id: UUID(), text: words, askedAt: now())
        questions[appID] = nil
        update(appID) { chat in
            chat.turns.append(turn)
            chat.draft = ""
            chat.isUnseen = false
        }
        guard let runID = await start(prompt, chat.sessionID) else {
            update(appID) { chat in
                chat.turns.removeAll { $0.id == turn.id }
                if chat.draft.isEmpty { chat.draft = words }
            }
            return .notStarted
        }
        update(appID) { chat in
            if let index = chat.turns.firstIndex(where: { $0.id == turn.id }) { chat.turns[index].runID = runID }
        }
        if let ended = earlyEnds.removeValue(forKey: runID) { runEnded(ended.run, log: ended.log, queued: ended.queued) }
        return .sent
    }

    /// Try Again: the failed or stopped turn's words, as a new turn.
    @discardableResult
    func retry(context: AssistantChatContext, start: StartRun) async -> SendOutcome {
        let appID = context.appID
        guard let last = chat(for: appID).last, !last.isWorking else { return .busy }
        update(appID) { $0.turns.removeLast() }
        return await send(last.text, context: context, start: start)
    }

    /// The run answering the app's working turn.
    func workingRunID(for appID: StoreApp.ID) -> ClaudeCodeRun.ID? {
        guard let last = chat(for: appID).last, last.isWorking else { return nil }
        return last.runID
    }

    /// `ask_in_chat`: the assistant asks the person. False when no chat
    /// turn works for the app, so the call is refused.
    func receive(_ question: AssistantChatQuestion, for appID: StoreApp.ID) -> Bool {
        guard chat(for: appID).isWorking else { return false }
        questions[appID] = question
        return true
    }

    /// A Claude Code run ended: the turn it answered says how. `log` is
    /// the server's, for what it suggested meanwhile; `queued` is the
    /// app's Review & Push queue, for a new version it queued.
    func runEnded(_ run: ClaudeCodeRun, log: [MCPLogEntry], queued: [PendingChange] = []) {
        guard run.purpose == .chat else { return }
        let appID = run.appID
        guard let index = chats[appID]?.turns.firstIndex(where: { $0.runID == run.id }) else {
            if chats[appID]?.last?.isWorking == true { earlyEnds[run.id] = (run, log, queued) }
            return
        }
        let state: AssistantChatTurn.State
        switch run.phase {
        case .finished:
            if let question = questions.removeValue(forKey: appID) {
                state = .needsYou(question)
            } else {
                let text = run.result?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let suggestions = AssistantChatSuggestions.make(
                    from: log, appName: run.appName, start: run.startedAt, end: run.endedAt ?? now(), queued: queued
                )
                state = .answered(text: text, suggestions: suggestions)
            }
        case .stopped:
            questions[appID] = nil
            state = .stopped
        case let .failed(failure):
            questions[appID] = nil
            state = .failed(failure)
        case .starting, .working:
            return
        }
        let seen = isOpen && shownAppID == appID
        update(appID) { chat in
            chat.turns[index].state = state
            chat.turns[index].endedAt = run.endedAt ?? now()
            if let session = run.sessionID ?? run.result?.sessionID { chat.sessionID = session }
            chat.isUnseen = !seen
        }
    }

    private func update(_ appID: StoreApp.ID, _ change: (inout AssistantChat) -> Void) {
        var chat = chats[appID] ?? AssistantChat()
        change(&chat)
        chats[appID] = chat
    }

    #if DEBUG
    /// A DEBUG scene's chat, as it would be after asking.
    func debugSet(_ chat: AssistantChat, for appID: StoreApp.ID, isOpen: Bool) {
        chats[appID] = chat
        self.isOpen = isOpen
    }
    #endif
}
