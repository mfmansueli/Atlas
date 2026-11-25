//
//  AssistantChatCorner.swift
//  Atlas
//

import SwiftUI

/// The chat with the assistant in the bottom-right corner of every section
/// (board 69). Closed, a pill that says what's happening; open (a click or
/// ⌘J), the conversation over the content, which doesn't move: the pill
/// grows into it from the corner and closing shrinks it back
/// (`AssistantChatOpening`). Esc, the arrow or a click on the content
/// closes it, and what was being written stays as a draft. Each question
/// starts Claude Code through the launcher; a follow-up continues its
/// session.
struct AssistantChatCorner: View {
    let context: AssistantChatContext
    let client: String
    /// Atlas can start the assistant (the helper is in place).
    let canAsk: Bool
    var center: AssistantChatCenter = .shared
    let onConnect: () -> Void
    let onShow: (AppWorkspaceSection) -> Void
    /// Opens Review & Push on a section's changes (nil: the app's).
    let onReview: (AppWorkspaceSection?) -> Void

    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(PushController.self) private var push
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let chat = center.chat(for: context.appID)
        let progress = progress(of: chat)
        let opening = AssistantChatOpening.style(reduceMotion: reduceMotion)
        GeometryReader { proxy in
            Group {
                if center.isOpen {
                    AssistantChatPanel(
                        chat: chat, context: context, client: client, canAsk: canAsk || chat.isWorking, progress: progress,
                        height: min(Metrics.chatPanelHeight, proxy.size.height - (Metrics.chatPanelClearance - Metrics.windowToolbarHeight)),
                        draft: draft, onSend: send, onStop: stop, onRetry: retry,
                        onShowOutput: { launcher.shownRunID = $0 },
                        onClose: { center.setOpen(false) },
                        onConnect: connect,
                        onShow: show,
                        onRemoveChip: { center.removeContext($0, for: context.appID) }
                    )
                    .closesOnOutsideClick(center.isOpen, keepsOpen: chat.hasDraft) { center.setOpen(false) }
                    .transition(opening.panelTransition)
                } else {
                    AssistantChatPill(
                        line: AssistantChatPillLine.make(inputs(chat: chat, progress: progress)), client: client,
                        onOpen: { center.setOpen(true) }, onAction: act
                    )
                    .transition(opening.pillTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        // Opening and closing: the pill grows into the panel and back.
        .animation(opening.token.animation, value: center.isOpen)
        .onChange(of: context.appID, initial: true) { _, appID in center.shownAppID = appID }
    }

    private var draft: Binding<String> {
        Binding { center.chat(for: context.appID).draft } set: { center.setDraft($0, for: context.appID) }
    }

    private func inputs(chat: AssistantChat, progress: AssistantChatProgress) -> AssistantChatPillLine.Inputs {
        AssistantChatPillLine.Inputs(
            appName: context.appName, client: client, canAsk: canAsk, chat: chat, progress: progress,
            push: push.sendingProgress.map { AssistantChatPillLine.PushProgress(sent: $0.sent, total: $0.total) }
        )
    }

    /// How far the working turn's answer has come, from its run: nothing
    /// yet (sending) until Claude Code reports a step.
    private func progress(of chat: AssistantChat) -> AssistantChatProgress {
        guard chat.isWorking, let id = chat.last?.runID, let run = launcher.run(id) else { return AssistantChatProgress() }
        return AssistantChatProgress.make(activity: run.activity, hasResult: run.result != nil)
    }

    private var start: AssistantChatCenter.StartRun {
        let launcher = launcher
        let context = context
        return { prompt, session in
            await launcher.start(.chat, appID: context.appID, appName: context.appName, prompt: prompt, resuming: session)
        }
    }

    private func send(_ text: String) {
        let start = start
        let context = context
        Task { await center.send(text, context: context, start: start) }
    }

    private func retry() {
        let start = start
        let context = context
        Task { await center.retry(context: context, start: start) }
    }

    private func stop() {
        guard let id = center.workingRunID(for: context.appID) else { return }
        launcher.stop(id)
    }

    private func connect() {
        center.setOpen(false)
        onConnect()
    }

    /// Where an answer's suggestions wait: Review & Push for a new version
    /// and its texts, else their section.
    private func show(_ suggestions: AssistantChatSuggestions) {
        center.setOpen(false)
        if suggestions.waitsInReview {
            onReview(suggestions.section)
        } else if let section = suggestions.section {
            onShow(section)
        }
    }

    private func act(_ action: AssistantChatPillLine.Action) {
        switch action {
        case .connect: connect()
        case .tryAgain: retry()
        }
    }
}
