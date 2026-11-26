//
//  WorkspaceAutopilotBar.swift
//  Atlas
//

import SwiftUI

/// The Autopilot bar at the bottom of every section (board 80), in place of
/// the toolbar's Autopilot button and the chat in the corner.
///
/// Closed: “Ask or tell Autopilot…”, the section's first two actions as
/// buttons (a click sends the request like a message), More with the rest
/// and Everything for the app, and ⌘J. A strip grows above the field when
/// something happens (`AutopilotBarStrip`): the step while it works, the
/// question while the assistant needs the person, Done with Show, or why it
/// stopped with Try Again.
///
/// Open (a click on the field or ⌘J): it grows up over the page into the
/// conversation. What Autopilot can do here, what finished earlier today,
/// each request and question with its steps and answer (suggestions come
/// back as cards with Accept), the field, and the connection. ⌄, ⌘J, Esc
/// or a click on the page make it small again; what was being written stays
/// as a draft. ⌥⌘A runs the section's own action.
struct WorkspaceAutopilotBar: View {
    let context: AssistantChatContext
    let actions: AutopilotBarActions
    let state: WorkspaceAutopilotState
    var runProgress: GuidedRunProgress?
    /// Atlas can start the assistant (the helper is in place).
    let canAsk: Bool
    /// How tall it may grow open.
    let openHeight: CGFloat
    /// Cancel Run…, while the guided run can be cancelled.
    var onCancelRun: (() -> Void)?
    /// Reply Automatically's pause, while it's on (board 58); nil when off.
    var autoReplyPaused: Bool?
    var onPauseAutoReply: (Bool) -> Void = { _ in }
    var onAutoReplySettings: () -> Void = {}

    let activity: AssistantActivity
    let status: AssistantStatus
    /// The client the menu names, once paired.
    var client: MCPPairedClient?
    /// What's true for the app on screen: connected here, in another
    /// project, or refused.
    var connection: AssistantConnection?
    var editsDrafts = false
    var recentCalls: [MCPLogEntry] = []
    /// Holds the Proposals sheet; nil when these services keep no screenshot
    /// documents.
    let documents: ScreenshotsDocumentCenter?
    /// The name of an app in the library, by Apple ID.
    let appName: (StoreApp.ID) -> String
    let onReviewProposals: (_ client: String?) -> Void
    var isSuggestingEverything = false
    /// On the Store Page or App Information: Ask About This Page….
    var canAskAboutPage = false
    var onAskAboutPage: () -> Void = {}
    var onSuggestEverything: () -> Void = {}
    var onSetUp: () -> Void = {}
    /// The app's last Claude Code run, while it's `.failed`.
    var failedRunID: ClaudeCodeRun.ID?
    var onForgetFailure: () -> Void = {}

    /// Runs one of the section's actions (Pro's ask for the paywall).
    let onAction: (WorkspaceAutopilotAction) -> Void
    /// Opens the guided run at its step, or where Autopilot waits.
    let onOpenRun: () -> Void
    /// Opens a section, where a request's suggestions wait.
    let onShow: (AppWorkspaceSection) -> Void
    /// Opens Review & Push on a section's changes (nil: the app's).
    let onReview: (AppWorkspaceSection?) -> Void
    /// The room the closed bar takes at the bottom of the page.
    var onRoom: (CGFloat) -> Void = { _ in }

    var chatCenter: AssistantChatCenter = .shared
    var barCenter: AutopilotBarCenter = .shared

    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(KeyAssistantController.self) private var keyAssistant
    @Environment(\.askCenterOverride) private var askCenterOverride
    @State private var isShowingPopover = false
    @State private var isConfirmingCancel = false
    @State private var isShowingFailure = false
    @State private var isActionsFolded = true
    @FocusState private var isFieldFocused: Bool

    private var askCenter: AssistantAskCenter { askCenterOverride ?? .shared }
    private var appID: StoreApp.ID { context.appID }
    private var chat: AssistantChat { chatCenter.chat(for: appID) }
    private var isOpen: Bool { chatCenter.isOpen }
    private var clientName: String { client?.name ?? status.clientName ?? MCPClientKind.claudeCode.title }

    var body: some View {
        let strip = AutopilotBarStrip.make(stripInputs)
        withEvents(
            withPresentations(
                AutopilotBarSurface(isOpen: isOpen, stripKind: strip?.kind, openHeight: openHeight) {
                    closedContent(strip)
                } open: {
                    openContent
                }
            ),
            strip: strip
        )
    }

    // MARK: - Closed

    private func closedContent(_ strip: AutopilotBarStrip?) -> some View {
        VStack(spacing: 0) {
            if let strip {
                AutopilotBarStripView(
                    strip: strip, onAction: { act(on: strip) }, onChoice: send, onStop: { stop(strip) }, onDismiss: { dismiss(strip) }
                )
                .transition(.opacity)
                Divider()
            }
            AutopilotBarClosedField(
                actions: actions, anchor: askCenter.barAnchor, sectionTitle: context.section.title,
                onOpen: { chatCenter.setOpen(true) }, onAction: send,
                more: { room in moreMenu(fitting: room) }
            )
        }
        .animation(MotionTiming.base.animation, value: strip?.kind)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { onRoom(AutopilotBarRoom.room(closedHeight: $0)) }
    }

    private func moreMenu(fitting room: Int) -> some View {
        AutopilotBarMoreMenu(
            items: actions.more(fitting: room), everythingTitle: actions.everythingTitle, isSuggestingEverything: isSuggestingEverything,
            state: state, runProgress: runProgress, canShowRun: canShowRun, canCancelRun: onCancelRun != nil,
            autoReplyPaused: autoReplyPaused, proposalCount: activity.proposalCount, connectionTitle: connectionTitle,
            onAction: send, onShowRun: onOpenRun, onCancelRun: { isConfirmingCancel = true },
            onPauseAutoReply: onPauseAutoReply, onAutoReplySettings: onAutoReplySettings, onSuggestEverything: onSuggestEverything,
            onReviewProposals: reviewProposals, onStatus: { isShowingPopover = true }
        )
    }

    private var canShowRun: Bool {
        switch state {
        case .running(_, true), .capturing, .needsYou, .finished: true
        default: false
        }
    }

    // MARK: - Open

    private var openContent: some View {
        let sent = barCenter.sent[appID]
        let earlier = barCenter.earlierToday(for: appID)
        let hasConversation = !chat.turns.isEmpty || sent != nil || !earlier.isEmpty
        return VStack(spacing: 0) {
            AutopilotBarHeader(
                isWorking: chat.isWorking || askCenter.ask(for: appID) != nil,
                chips: context.chips(removing: chat.removedContext),
                onClose: { chatCenter.setOpen(false) },
                onRemoveChip: { chatCenter.removeContext($0, for: appID) }
            )
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    AutopilotBarActionsList(
                        sectionTitle: context.section.title, actions: actions, isFolded: $isActionsFolded, canFold: hasConversation,
                        onAction: send, onEverything: onSuggestEverything
                    )
                    if !earlier.isEmpty {
                        AutopilotBarEarlierList(items: earlier) { item in
                            chatCenter.setOpen(false)
                            onShow(item.section)
                        }
                    }
                    AutopilotBarConversation(
                        chat: chat, progress: progress(of: chat.last?.isWorking == true ? chat.last?.runID : nil), client: clientName,
                        appName: context.appName, canAsk: canAsk, starters: AssistantChatStarters.starters(for: context.section),
                        sent: sent, sentSubject: askCenter.ask(for: appID)?.subject,
                        sentProgress: progress(of: askCenter.ask(for: appID)?.runID),
                        onSend: send, onRetry: retry, onShowOutput: { launcher.shownRunID = $0 }, onShow: show, onConnect: connect
                    )
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.medium)
            }
            .defaultScrollAnchor(.bottom)
            .scrollBounceBehavior(.basedOnSize)
            if let note {
                Text(note)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.large)
                    .padding(.bottom, Spacing.xxSmall)
                    .accessibilityIdentifier("chat.note")
            }
            Divider()
            AutopilotBarInput(
                text: draft, placeholder: placeholder, isWorking: chat.isWorking, isEnabled: canAsk || chat.isWorking,
                anchor: askCenter.barAnchor, isFocused: $isFieldFocused, onSend: { send(draft.wrappedValue) }, onStop: stopChat
            )
            Divider()
            AutopilotBarFooter(connection: canAsk ? connectionTitle : nil, onConnect: connect)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.panel")
        .onAppear { if canAsk { isFieldFocused = true } }
    }

    private var draft: Binding<String> {
        Binding { chatCenter.chat(for: appID).draft } set: { chatCenter.setDraft($0, for: appID) }
    }

    private var placeholder: String {
        if !canAsk { return String(localized: "No assistant connected", comment: "kind:placeholder · the Autopilot bar's field") }
        if chat.question != nil { return String(localized: "Or write your answer…", comment: "kind:placeholder · the Autopilot bar's field") }
        if chat.turns.isEmpty { return String(localized: "Ask about \(context.appName)…", comment: "kind:placeholder · the Autopilot bar's field") }
        return String(localized: "Ask a follow-up…", comment: "kind:placeholder · the Autopilot bar's field")
    }

    /// The safety line, once: under an answer that suggested something.
    private var note: String? {
        guard let suggestions = chat.last?.suggestions else { return nil }
        if suggestions.waitsInReview {
            return String(
                localized: "They wait in Review & Push. Nothing is sent until you push.", comment: "kind:footnote · under an Autopilot answer's suggestions"
            )
        }
        guard let section = suggestions.section else { return nil }
        return String(
            localized: "Accept them here or in \(section.title). Nothing is sent until you push.", comment: "kind:footnote · under an Autopilot answer's suggestions"
        )
    }
}

// MARK: - Strip

extension WorkspaceAutopilotBar {
    private var stripInputs: AutopilotBarStrip.Inputs {
        let ask = askCenter.ask(for: appID)
        return AutopilotBarStrip.Inputs(
            client: clientName, state: state, runProgress: runProgress, canCancelRun: onCancelRun != nil,
            ask: ask, askProgress: progress(of: ask?.runID), sent: barCenter.sent[appID],
            chat: chat, chatProgress: progress(of: chat.isWorking ? chat.last?.runID : nil),
            done: barCenter.done[appID], dismissed: barCenter.dismissedKeys(for: appID),
            canRetryFailure: barCenter.failed[appID]?.action != nil, isOpen: isOpen
        )
    }

    /// How far a run has come, from its steps: nothing yet (sending)
    /// until Claude Code reports one.
    private func progress(of runID: ClaudeCodeRun.ID?) -> AssistantChatProgress {
        guard let runID, let run = launcher.run(runID) else { return AssistantChatProgress() }
        return AssistantChatProgress.make(activity: run.activity, hasResult: run.result != nil)
    }

    private func act(on strip: AutopilotBarStrip) {
        switch strip.action {
        case .show:
            switch strip.source {
            case .ask:
                barCenter.dismiss(strip.key, appID: appID)
                if let done = barCenter.finished[appID]?.first(where: { $0.key == strip.key }) { onShow(done.section) }
            case .run, .assistant, .chat, .failedRun:
                if case .finished = state { barCenter.dismiss(strip.key, appID: appID) }
                if strip.source == .assistant { isShowingPopover = true } else { onOpenRun() }
            }
        case .open:
            chatCenter.setOpen(true)
        case .tryAgain:
            if strip.source == .chat {
                retry()
            } else if let request = barCenter.failed[appID], let action = request.action {
                barCenter.forgetFailure(appID: appID)
                onForgetFailure()
                if let item = actions.items.first(where: { $0.action == action }) { send(item) } else { onAction(action) }
            }
        case .details:
            if failedRunID != nil { isShowingFailure = true } else { isShowingPopover = true }
        case nil:
            break
        }
    }

    private func stop(_ strip: AutopilotBarStrip) {
        switch strip.source {
        case .ask: if let id = askCenter.ask(for: appID)?.runID { launcher.stop(id) }
        case .chat: stopChat()
        case .run: isConfirmingCancel = true
        case .assistant, .failedRun: break
        }
    }

    private func dismiss(_ strip: AutopilotBarStrip) {
        barCenter.dismiss(strip.key, appID: appID)
        switch strip.source {
        case .chat: if strip.kind == .done { chatCenter.markSeen(appID) }
        case .failedRun:
            barCenter.forgetFailure(appID: appID)
            onForgetFailure()
        case .ask, .run, .assistant: break
        }
    }
}

// MARK: - Asking

extension WorkspaceAutopilotBar {
    /// One of the section's actions, sent like a message: the person's
    /// bubble in the conversation while the assistant works on it.
    private func send(_ item: WorkspaceAutopilotItem) {
        barCenter.send(AutopilotBarRequest(
            appID: appID, title: item.action.shortTitle(fullTitle: item.title), action: item.action, section: context.section, sentAt: .now
        ))
        onAction(item.action)
        // A section's own flow, the paywall, or a copied prompt: nothing
        // runs here, so no bubble stays.
        if askCenter.ask(for: appID) == nil { barCenter.withdraw(appID: appID) }
    }

    private var start: AssistantChatCenter.StartRun {
        let launcher = launcher
        let context = context
        return { prompt, session in
            await launcher.start(.chat, appID: context.appID, appName: context.appName, prompt: prompt, resuming: session)
        }
    }

    /// A typed question, a starter or an answer to the assistant's question.
    private func send(_ text: String) {
        let start = start
        let context = context
        let center = chatCenter
        Task { await center.send(text, context: context, start: start) }
    }

    private func retry() {
        let start = start
        let context = context
        let center = chatCenter
        Task { await center.retry(context: context, start: start) }
    }

    private func stopChat() {
        guard let id = chatCenter.workingRunID(for: appID) else { return }
        launcher.stop(id)
    }

    private func connect() {
        chatCenter.setOpen(false)
        onSetUp()
    }

    /// Where an answer's suggestions wait: Review & Push for a new version
    /// and its texts, else their section.
    private func show(_ suggestions: AssistantChatSuggestions) {
        chatCenter.setOpen(false)
        if suggestions.waitsInReview {
            onReview(suggestions.section)
        } else if let section = suggestions.section {
            onShow(section)
        }
    }

    /// ⌥⌘A: where Autopilot waits for the person, else the section's own
    /// action.
    private func runPrimary() {
        if case .needsYou = state {
            onOpenRun()
        } else if let primary = actions.primary {
            send(primary)
        }
    }
}

// MARK: - Status

extension WorkspaceAutopilotBar {
    /// “Claude Code · Connected”.
    private var connectionTitle: String {
        let line = status.isConnected ? connection?.statusTitle ?? status.title : status.title
        return "\(clientName) · \(line)"
    }

    /// The app whose screenshot proposals open: the one with the most.
    private var screenshotApp: StoreApp.ID? {
        activity.screenshotApps.map(\.appID).first { documents?.canOpenProposals(appID: $0) == true }
    }

    private var presentedProposals: Binding<ScreenshotProposalsViewModel?> {
        Binding { documents?.presentedProposals } set: { documents?.presentedProposals = $0 }
    }

    private func reviewProposals() {
        isShowingPopover = false
        if activity.reviewCount == 0, let screenshotApp {
            documents?.openProposals(appID: screenshotApp)
        } else {
            onReviewProposals(activity.leadingReviewClient ?? activity.leadingClient)
        }
    }

    private var popover: some View {
        AssistantPopoverContent(
            ask: askCenter.ask(for: appID),
            status: status,
            activity: activity,
            client: client,
            connection: status.isConnected ? connection : nil,
            editsDrafts: editsDrafts,
            recentCalls: recentCalls,
            key: keyAssistant.configuration,
            recentRequests: keyAssistant.recentRequests,
            appName: appName,
            canOpenScreenshotProposals: screenshotApp != nil,
            isSuggestingEverything: isSuggestingEverything,
            canAskAboutPage: canAskAboutPage,
            onReviewProposals: reviewProposals,
            onScreenshotProposals: {
                isShowingPopover = false
                if let screenshotApp { documents?.openProposals(appID: screenshotApp) }
            },
            onAsk: {
                isShowingPopover = false
                onAskAboutPage()
            },
            onSuggestEverything: {
                isShowingPopover = false
                onSuggestEverything()
            },
            onSetUp: {
                isShowingPopover = false
                onSetUp()
            }
        )
    }

    // MARK: - Presentations and events

    private func withPresentations(_ content: some View) -> some View {
        content
            .closesOnOutsideClick(isOpen, keepsOpen: chat.hasDraft) { chatCenter.setOpen(false) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Autopilot", comment: "kind:accessibility · the bar at the bottom of every section"))
            .accessibilityIdentifier("autopilotBar")
            .tourTip(.autopilot, arrowEdge: .top)
            .popover(isPresented: $isShowingPopover, arrowEdge: .top) { popover }
            .sheet(item: presentedProposals) { proposals in
                ScreenshotProposalsSheet(viewModel: proposals)
                    .pageControlSize()
            }
            .confirmationDialog("Cancel the run?", isPresented: $isConfirmingCancel) {
                Button("Cancel Run", role: .destructive) { onCancelRun?() }
                Button("Keep Running", role: .cancel) {}
            } message: {
                if case .capturing = state {
                    Text("Screenshots it already made stay as suggestions.")
                } else {
                    Text("Its work so far is dropped. Captures stay for next time.")
                }
            }
            .sheet(isPresented: $isShowingFailure, onDismiss: onForgetFailure) {
                if let failedRunID { ClaudeCodeRunOutputSheet(runID: failedRunID).pageControlSize() }
            }
    }

    private func withEvents(_ content: some View, strip: AutopilotBarStrip?) -> some View {
        content
            .onChange(of: appID, initial: true) { _, appID in chatCenter.shownAppID = appID }
            .onChange(of: isOpen) { _, open in
                if open { barCenter.opened(appID: appID) }
            }
            .onChange(of: navigator.requestsAssistantPopover, initial: true) {
                guard navigator.requestsAssistantPopover else { return }
                navigator.requestsAssistantPopover = false
                isShowingPopover = true
            }
            .onChange(of: navigator.requestsAutopilot, initial: true) {
                guard navigator.requestsAutopilot else { return }
                navigator.requestsAutopilot = false
                runPrimary()
            }
            // A change in what the strip says is said once, politely.
            .onChange(of: strip?.announcementKey) {
                guard let strip else { return }
                announce(strip.title)
            }
            #if DEBUG
            .task {
                if Self.debugShowsPopover {
                    Self.debugShowsPopover = false
                    isShowingPopover = true
                }
            }
            #endif
    }

    /// Says a change once, politely: “Autopilot, done, Store Page, German”.
    private func announce(_ text: String) {
        var announcement = AttributedString(AutopilotBarStrip.announcement(text))
        announcement.accessibilitySpeechAnnouncementPriority = .low
        AccessibilityNotification.Announcement(announcement).post()
    }
}
