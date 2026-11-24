//
//  AssistantChatCorner.swift
//  Atlas
//

import SwiftUI

/// The chat with the assistant in the bottom-right corner of every section
/// (board 69). Closed, a pill that says what's happening; open (a click or
/// ⌘J), the conversation over the content, which doesn't move. Esc, the
/// arrow or a click on the content closes it, and what was being written
/// stays as a draft. Each question starts Claude Code through the
/// launcher; a follow-up continues its session.
struct AssistantChatCorner: View {
    let context: AssistantChatContext
    let client: String
    /// Atlas can start the assistant (the helper is in place).
    let canAsk: Bool
    var center: AssistantChatCenter = .shared
    let onConnect: () -> Void
    let onShow: (AppWorkspaceSection) -> Void

    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(PushController.self) private var push

    var body: some View {
        let chat = center.chat(for: context.appID)
        let steps = steps(of: chat)
        GeometryReader { proxy in
            Group {
                if center.isOpen {
                    AssistantChatPanel(
                        chat: chat, context: context, client: client, canAsk: canAsk || chat.isWorking, steps: steps,
                        height: min(Metrics.chatPanelHeight, proxy.size.height - (Metrics.chatPanelClearance - Metrics.windowToolbarHeight)),
                        draft: draft, onSend: send, onStop: stop, onRetry: retry,
                        onShowOutput: { launcher.shownRunID = $0 },
                        onClose: { center.setOpen(false) },
                        onConnect: connect,
                        onShow: show,
                        onRemoveChip: { center.removeContext($0, for: context.appID) }
                    )
                    .closesOnOutsideClick(center.isOpen, keepsOpen: chat.hasDraft) { center.setOpen(false) }
                    .transition(.opacity)
                } else {
                    AssistantChatPill(
                        line: AssistantChatPillLine.make(inputs(chat: chat, steps: steps)), client: client,
                        onOpen: { center.setOpen(true) }, onAction: act
                    )
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .animation(MotionTiming.fast.animation, value: center.isOpen)
        .onChange(of: context.appID, initial: true) { _, appID in center.shownAppID = appID }
    }

    private var draft: Binding<String> {
        Binding { center.chat(for: context.appID).draft } set: { center.setDraft($0, for: context.appID) }
    }

    private func inputs(chat: AssistantChat, steps: [AssistantChatStep]) -> AssistantChatPillLine.Inputs {
        AssistantChatPillLine.Inputs(
            appName: context.appName, client: client, canAsk: canAsk, chat: chat, steps: steps,
            push: push.sendingProgress.map { AssistantChatPillLine.PushProgress(sent: $0.sent, total: $0.total) }
        )
    }

    /// The working turn's steps, from its run.
    private func steps(of chat: AssistantChat) -> [AssistantChatStep] {
        guard chat.isWorking, let id = chat.last?.runID, let run = launcher.run(id) else { return [] }
        return AssistantChatStep.steps(from: run.activity)
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

    private func show(_ section: AppWorkspaceSection) {
        center.setOpen(false)
        onShow(section)
    }

    private func act(_ action: AssistantChatPillLine.Action) {
        switch action {
        case .connect: connect()
        case .tryAgain: retry()
        }
    }
}
