//
//  AutopilotToolbarButton.swift
//  Atlas
//

import SwiftUI

/// The toolbar's Autopilot button, the same place in every section (board
/// 57): a split button with the sparkle, whose label is what Autopilot
/// makes here (“Make Screenshots…”, “Suggest Texts…”). A click runs it
/// (⌥⌘A); the arrow lists everything Autopilot can do in the section, then
/// Everything for the app (Suggest Everything), then the assistant's
/// connection, whose status popover (recent calls, proposals waiting) was
/// the Assistant button's, and Settings….
///
/// It's also the run's status, and it moves only while something really
/// runs for the app (“While it works”): a light travels along its edge, the
/// sparkle's stars twinkle, a 2 pt bar fills when the run counts its steps,
/// and a green check draws itself when it's done. Needing the person it's
/// solid purple with what it needs, and a click opens that step; a run that
/// stopped says what stopped, and a click opens the reason. Reduce Motion
/// keeps it all still. A request sent from an asking button lands on it
/// (board 56). On Free, an action that's part of Pro shows PRO and opens
/// the paywall.
///
/// A toolbar `Menu` draws only an image and a title, so the split is built
/// by hand: a button with the animated label, and a menu with the arrow, on
/// their own glass capsule.
struct AutopilotToolbarButton: View {
    /// The section's actions, the button's own first.
    let items: [WorkspaceAutopilotItem]
    /// “Everything for Lumen…”; nil where it's the button's own action.
    var everythingTitle: String?
    let state: WorkspaceAutopilotState
    /// The guided run's progress, for the menu while it works.
    var runProgress: GuidedRunProgress?
    var isCompact = false
    let onAction: (WorkspaceAutopilotAction) -> Void
    /// Opens the guided run at its step.
    var onOpenRun: () -> Void = {}
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
    let center: ScreenshotsDocumentCenter?
    /// The name of an app in the library, by Apple ID.
    let appName: (StoreApp.ID) -> String
    let onReview: (_ client: String?) -> Void
    /// Suggest Everything is receiving: Show Progress.
    var isSuggestingEverything = false
    /// On the Store Page or App Information: Ask About This Page….
    var canAskAboutPage = false
    var onAsk: () -> Void = {}
    var onSuggestEverything: () -> Void = {}
    var onSetUp: () -> Void = {}
    /// The app's request from an asking button, while it runs.
    var ask: AssistantAsk?
    /// The app's last Claude Code run, while it's `.failed`: a click shows
    /// its output, and closing that forgets it.
    var failedRunID: ClaudeCodeRun.ID?
    var onForgetFailure: () -> Void = {}
    @Environment(\.askCenterOverride) private var askCenterOverride
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(KeyAssistantController.self) private var keyAssistant
    @State private var isShowingPopover = false
    @State private var isConfirmingCancel = false
    @State private var isShowingFailure = false
    /// “Done · Store Page · German” while the check shows.
    @State private var doneText: String?
    /// Bumped when a run is done: the button bounces once, the check stays
    /// about 2 s.
    @State private var doneCount = 0

    private var askCenter: AssistantAskCenter { askCenterOverride ?? .shared }

    private var primary: WorkspaceAutopilotItem? { items.first }

    private var look: AutopilotButtonLook {
        AutopilotButtonLook(state: state, done: doneText, runProgress: runProgress)
    }

    var body: some View {
        withEvents(withPresentations(decorated))
    }

    /// The split, drawn by `AutopilotButtonFace`. Once, after an assistant
    /// first connects, a purple sheen crosses it (effect 6).
    private var decorated: some View {
        AutopilotButtonFace(
            look: look, title: primary?.title, isPro: primary?.isPro == true, isCompact: isCompact, doneCount: doneCount,
            accessibilityLabel: accessibilityLabel, onMain: runPrimary
        ) {
            menu
        }
        .modifier(AutopilotGlint())
    }

    private func withPresentations(_ content: some View) -> some View {
        content
            .background(AskAnchorView(anchor: askCenter.toolbarAnchor))
            .help(accessibilityLabel)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityIdentifier("workspace.autopilot")
            .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) { popover }
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
            // A run that ends by itself shows the check for about 2 s.
            .onChange(of: state) { old, new in
                if let done = old.doneText(becoming: new) {
                    doneText = done
                    doneCount += 1
                    announce(done)
                } else if new.isRunning || new.text != nil {
                    doneText = nil
                }
            }
            .task(id: doneCount) {
                guard doneText != nil else { return }
                try? await Task.sleep(for: AutopilotButtonLook.doneDuration)
                if !Task.isCancelled { doneText = nil }
            }
    }

    private func withEvents(_ content: some View) -> some View {
        content
            .onChange(of: navigator.requestsAssistantPopover, initial: true) {
                guard navigator.requestsAssistantPopover else { return }
                navigator.requestsAssistantPopover = false
                isShowingPopover = true
            }
            // A change in the run's state is said once, politely.
            .onChange(of: state.announcementKey) {
                guard let text = state.text else { return }
                announce(text)
            }
            .onChange(of: navigator.requestsAutopilot, initial: true) {
                guard navigator.requestsAutopilot else { return }
                navigator.requestsAutopilot = false
                runPrimary()
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

    // MARK: - VoiceOver

    /// Says a change once, politely: “Autopilot, done, Store Page, German”.
    private func announce(_ text: String) {
        var announcement = AttributedString(Self.announcement(text))
        announcement.accessibilitySpeechAnnouncementPriority = .low
        AccessibilityNotification.Announcement(announcement).post()
    }

    // MARK: - Menu

    @ViewBuilder
    private var menu: some View {
        if let autoReplyPaused {
            Section(autoReplyPaused ? String(localized: "Auto-reply paused") : String(localized: "Replying automatically")) {
                Button(autoReplyPaused ? String(localized: "Resume Auto-Reply") : String(localized: "Pause Auto-Reply")) {
                    onPauseAutoReply(!autoReplyPaused)
                }
                .accessibilityIdentifier("workspace.autopilot.autoReplyPause")
                Button("Auto-Reply Settings…", action: onAutoReplySettings)
            }
        }
        if let text = state.text, !state.isOn {
            Section(text) {
                if let runProgress {
                    Text(runProgress.line)
                }
                if state.isRunning ? isScreenshotRun : true {
                    Button("Show Run…", action: onOpenRun)
                }
                if onCancelRun != nil {
                    Button("Cancel Run…", role: .destructive) { isConfirmingCancel = true }
                        .accessibilityIdentifier("workspace.autopilot.cancel")
                }
            }
        }
        Section {
            ForEach(items) { item in
                Button {
                    onAction(item.action)
                } label: {
                    Label {
                        Text(item.isPro ? String(localized: "\(item.title) · PRO") : item.title)
                        if let note = item.note { Text(note) }
                    } icon: {
                        Image(systemName: item.action.systemImage)
                    }
                }
                .disabled(!item.isEnabled)
            }
        }
        if let everythingTitle {
            Section {
                Button(isSuggestingEverything ? String(localized: "Show Suggest Everything’s Progress") : everythingTitle) {
                    onSuggestEverything()
                }
                .accessibilityIdentifier("workspace.autopilot.everything")
            }
        }
        Section {
            if activity.proposalCount > 0 {
                Button(activity.proposalCount == 1 ? String(localized: "1 Suggestion to Review…") : String(localized: "\(activity.proposalCount) Suggestions to Review…")) {
                    reviewProposals()
                }
            }
            Button(connectionTitle) { isShowingPopover = true }
                .accessibilityIdentifier("workspace.autopilot.status")
            SettingsLink {
                Text("Settings…")
            }
        }
    }

    private var isScreenshotRun: Bool {
        if case .running(_, true) = state { return true }
        return false
    }

    /// “Claude Code · Connected”.
    private var connectionTitle: String {
        let name = client?.name ?? status.clientName ?? MCPClientKind.claudeCode.title
        let line = status.isConnected ? connection?.statusTitle ?? status.title : status.title
        return "\(name) · \(line)"
    }

    private var popover: some View {
        AssistantPopoverContent(
            ask: ask,
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
                if let screenshotApp { center?.openProposals(appID: screenshotApp) }
            },
            onAsk: {
                isShowingPopover = false
                onAsk()
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

    // MARK: - Actions

    /// Needing the person: that step. Running: the run, or what the
    /// assistant is doing. Else the section's action.
    private func runPrimary() {
        if ask != nil {
            isShowingPopover = true
            return
        }
        switch state {
        case .needsYou:
            onOpenRun()
        case .failed:
            if failedRunID != nil { isShowingFailure = true } else { isShowingPopover = true }
        case .running:
            if isScreenshotRun { onOpenRun() } else { isShowingPopover = true }
        case .capturing:
            onOpenRun()
        case .idle, .autoReplyOn:
            if let primary { onAction(primary.action) }
        }
    }

    /// “Autopilot, Make Screenshots”, “Autopilot, making screenshots, 5 of
    /// 10 captures”.
    private var accessibilityLabel: String {
        if let doneText { return Self.announcement(doneText) }
        if let ask { return [ask.toolbarLabel, look.spokenProgress].compactMap(\.self).joined(separator: ", ") }
        if let text = state.text {
            let spoken = String(localized: "Autopilot, \(text.replacingOccurrences(of: " · ", with: ", "))")
            return [spoken, look.spokenProgress].compactMap(\.self).joined(separator: ", ")
        }
        let title = primary.map { $0.title.replacingOccurrences(of: "…", with: "") } ?? ""
        return String(localized: "Autopilot, \(title)")
    }

    /// What VoiceOver says when the state changes: "Autopilot, making
    /// screenshots, 5 of 10 captures".
    nonisolated static func announcement(_ stateText: String) -> String {
        String(localized: "Autopilot, \(stateText.replacingOccurrences(of: " · ", with: ", "))")
    }

    /// The app whose screenshot proposals open: the one with the most.
    private var screenshotApp: StoreApp.ID? {
        activity.screenshotApps.map(\.appID).first { center?.canOpenProposals(appID: $0) == true }
    }

    private var presentedProposals: Binding<ScreenshotProposalsViewModel?> {
        Binding { center?.presentedProposals } set: { center?.presentedProposals = $0 }
    }

    private func reviewProposals() {
        isShowingPopover = false
        if activity.reviewCount == 0, let screenshotApp {
            center?.openProposals(appID: screenshotApp)
        } else {
            onReview(activity.leadingReviewClient ?? activity.leadingClient)
        }
    }
}
