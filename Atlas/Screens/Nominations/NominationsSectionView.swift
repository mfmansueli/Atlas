//
//  NominationsSectionView.swift
//  Atlas
//

import SwiftUI

/// The Nominations section of an app's workspace (⇧⌘F, board 70): builds
/// the view model, reads the nominations, and handles Ask Claude Code…,
/// the confirmation sheets and the toast. The toolbar's Autopilot asks
/// (`NominationsAskPrompt`) start from the toolbar itself.
struct NominationsSectionView: View {
    let app: StoreApp
    let services: WorkspaceServices

    @State private var viewModel: NominationsViewModel?
    @Environment(ChangeQueue.self) private var queue
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(NominationsStore.self) private var injectedStore: NominationsStore?
    @Environment(PushHistory.self) private var history: PushHistory?
    @Environment(ClaudeCodeLauncher.self) private var launcher: ClaudeCodeLauncher?
    @Environment(MCPServerController.self) private var assistants: MCPServerController?
    @Environment(\.askCenterOverride) private var askCenterOverride
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            if let viewModel, viewModel.app.id == app.id {
                content(viewModel)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.nominations")
        .task(id: app.id) { await start() }
        .onChange(of: navigator.refreshCount) {
            Task { await viewModel?.load(force: true) }
        }
    }

    private var store: NominationsStore { injectedStore ?? .shared }

    private func content(_ viewModel: NominationsViewModel) -> some View {
        NominationsScreen(
            viewModel: viewModel,
            actions: NominationsScreen.Actions(
                ask: { ask(NominationsAskPrompt.suggest(app: app.name)) },
                changeKey: changeKey,
                openReviewPush: { navigator.isReviewPresented = true },
                openEvents: { navigator.open(.inAppEvents, appID: app.id) }
            )
        )
        .sheet(item: Binding { viewModel.sheet } set: { viewModel.sheet = $0 }) { sheet in
            if let nomination = viewModel.nomination(sheet.nominationID) {
                NominationConfirmSheet(sheet: sheet, nomination: nomination, viewModel: viewModel)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                ActionToast(message: toast) {
                    viewModel.undo()
                } onAction: {
                    viewModel.toast = nil
                    navigator.isReviewPresented = true
                } onDismiss: {
                    if viewModel.toast == toast { viewModel.toast = nil }
                }
                .padding(.bottom, Spacing.large)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: viewModel.toast)
    }

    private func start() async {
        let model = viewModel?.app.id == app.id
            ? viewModel ?? NominationsViewModel(app: app, services: services.nominations, store: store, queue: queue)
            : NominationsViewModel(app: app, services: services.nominations, store: store, queue: queue)
        model.pushHistory = history
        #if DEBUG
        let launch = NominationsDebugLaunch.pending
        NominationsDebugLaunch.pending = nil
        launch?.prepare(model)
        #endif
        viewModel = model
        await model.load()
        #if DEBUG
        launch?.apply(to: model)
        #endif
    }

    /// Ask Claude Code…: the run starts (or its prompt is copied); what it
    /// suggests arrives over MCP.
    private func ask(_ ask: WorkspaceAutopilotAsk) {
        guard let launcher else { return }
        let client = assistants?.sessions.first?.displayName ?? MCPClientKind.claudeCode.title
        let outcome = AssistantAskStarter.start(
            ask, app: app, client: client, launcher: launcher, askCenter: askCenterOverride ?? .shared, reduceMotion: reduceMotion
        )
        switch outcome {
        case .sent: break
        case .copied: navigator.toast = WorkspaceToast(message: ToastMessage(text: AssistantAskStarter.copiedText(client: client)))
        case .busy: navigator.toast = WorkspaceToast(message: ToastMessage(text: AssistantAsk.busyTitle(client: client)))
        }
    }

    /// Change Key…: Settings → Accounts.
    private func changeKey() {
        SettingsNavigation.shared.pane = .accounts
        openSettings()
    }
}
