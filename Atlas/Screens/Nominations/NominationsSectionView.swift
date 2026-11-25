//
//  NominationsSectionView.swift
//  Atlas
//

import SwiftUI

/// The Nominations section of an app's workspace (⇧⌘F, board 70): builds
/// the view model, reads the nominations, and handles the confirmation
/// sheets and the toast. The toolbar's Autopilot asks
/// (`NominationsAskPrompt`) start from the toolbar itself.
struct NominationsSectionView: View {
    let app: StoreApp
    let services: WorkspaceServices

    @State private var viewModel: NominationsViewModel?
    @Environment(ChangeQueue.self) private var queue
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(NominationsStore.self) private var injectedStore: NominationsStore?
    @Environment(PushHistory.self) private var history: PushHistory?
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
        // New Nomination… in the toolbar: off until they're read.
        .reportsPageAction(pageActionState, for: .nominations)
        .task(id: app.id) { await start() }
        .onChange(of: navigator.refreshCount) {
            Task { await viewModel?.load(force: true) }
        }
        .onChange(of: navigator.intent) { handleIntent() }
    }

    /// New Nomination… in the toolbar, for this app's nominations.
    private var pageActionState: WorkspacePageActionState {
        guard let viewModel, viewModel.app.id == app.id else { return .disabled(reason: nil) }
        return viewModel.pageActionState
    }

    /// The toolbar's New Nomination…, once the nominations are read.
    private func handleIntent() {
        guard let viewModel, viewModel.app.id == app.id, viewModel.state.value != nil, navigator.intent == .pageAction,
              navigator.requestedAppID.map({ $0 == app.id }) ?? true else { return }
        navigator.consume(.pageAction)
        viewModel.startPageAction()
    }

    private var store: NominationsStore { injectedStore ?? .shared }

    private func content(_ viewModel: NominationsViewModel) -> some View {
        NominationsScreen(
            viewModel: viewModel,
            actions: NominationsScreen.Actions(
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
        handleIntent()
    }

    /// Change Key…: Settings → Accounts.
    private func changeKey() {
        SettingsNavigation.shared.pane = .accounts
        openSettings()
    }
}
