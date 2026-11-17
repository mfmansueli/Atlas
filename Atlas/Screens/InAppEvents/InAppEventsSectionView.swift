//
//  InAppEventsSectionView.swift
//  Atlas
//

import SwiftUI

/// The In-App Events section of an app's workspace (⌘4): builds the view
/// model (the window keeps it while other sections show), reads the
/// events, and tells it the store page's languages and which events go to
/// App Review with the version.
struct InAppEventsSectionView: View {
    let app: StoreApp
    let services: WorkspaceServices

    @State private var viewModel: InAppEventsViewModel?
    @State private var confirmsSubmit = false
    @Environment(InAppEventsStore.self) private var store
    @Environment(ReleaseStore.self) private var releases
    @Environment(ChangeQueue.self) private var queue
    @Environment(AppSummaryStore.self) private var summaries
    @Environment(WorkspaceNavigator.self) private var navigator
    /// The window's kept models; nil in previews without the main window.
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?

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
        .accessibilityIdentifier("workspace.inAppEvents")
        .task(id: app.id) { await start() }
        .onChange(of: navigator.refreshCount) {
            Task { await reload() }
        }
        .onChange(of: navigator.intent) { handleIntent() }
        .onChange(of: summaries.storePage[app.id]?.value) { configure() }
        .onChange(of: releases.archive) { configure() }
    }

    private func content(_ viewModel: InAppEventsViewModel) -> some View {
        InAppEventsScreen(viewModel: viewModel, onFooterAction: { footerAction(viewModel) })
            .sheet(isPresented: Binding { viewModel.isNewEventPresented } set: { viewModel.isNewEventPresented = $0 }) {
                NewInAppEventSheet(appName: app.name, primaryLocale: app.primaryLocale ?? "en-US") { event in
                    viewModel.problem(for: event)
                } onCancel: {
                    viewModel.isNewEventPresented = false
                } onAdd: { event in
                    let added = viewModel.add(event)
                    if added { viewModel.isNewEventPresented = false }
                    return added
                }
            }
            .confirmationDialog(
                String(localized: "Submit “\(viewModel.selectedEvent.map(ReleaseViewModel.displayName) ?? "")” to App Review?"),
                isPresented: $confirmsSubmit, titleVisibility: .visible
            ) {
                Button("Submit Event") {
                    Task { await viewModel.submitSelectedEvent(using: services.release, platform: release?.status?.version.platform) }
                }
                .accessibilityIdentifier("events.submit.confirm")
                Button("Not Now", role: .cancel) {}
            } message: {
                Text("It goes to App Review on its own, without a version. Its texts can’t be changed while it’s in review.")
            }
            .overlay(alignment: .bottom) {
                if let toast = viewModel.toast {
                    ActionToast(message: toast) {
                        viewModel.undoAccept()
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

    /// The version on its way to the App Store, read by the main window.
    private var release: ReleaseViewModel? {
        sectionModels?.models(for: app.id).release
    }

    private func start() async {
        let kept = sectionModels?.models(for: app.id)
        let model = kept?.events ?? InAppEventsViewModel(app: app, services: services.inAppEvents, store: store, queue: queue)
        kept?.events = model
        viewModel = model
        configure()
        #if DEBUG
        let launch = InAppEventsDebugLaunch.pending
        InAppEventsDebugLaunch.pending = nil
        #endif
        await model.load()
        #if DEBUG
        launch?.apply(to: model)
        #endif
        handleIntent()
        await summaries.load(app)
        configure()
        await loadResults(model)
    }

    private func reload() async {
        guard let viewModel else { return }
        await viewModel.load(force: true)
        await loadResults(viewModel)
    }

    /// Apple's numbers for the events that are over.
    private func loadResults(_ model: InAppEventsViewModel) async {
        for event in model.events where event.state.isOver && model.results[event.id] == nil {
            model.results[event.id] = await services.inAppEvents.results(for: event, of: app)
        }
    }

    /// The store page's languages, and the events that go with the version.
    private func configure() {
        guard let viewModel else { return }
        viewModel.pageLocales = summaries.storePage[app.id]?.value?.localeCodes ?? []
        let release = release
        let version = release?.versionString ?? releases.snapshot(for: app.id)?.versionString ?? ""
        viewModel.versionString = version.isEmpty ? nil : version
        viewModel.versionEventIDs = Set(release?.eventsGoingWithVersion.map(\.id) ?? releases.eventIDs(for: app.id))
    }

    /// The Overview's version card opens the event that goes with it.
    private func handleIntent() {
        guard let viewModel, case let .showInAppEvents(eventID) = navigator.intent, viewModel.state.value != nil,
              navigator.requestedAppID.map({ $0 == app.id }) ?? true else { return }
        navigator.consume(.showInAppEvents(eventID: eventID))
        if let eventID, viewModel.events.contains(where: { $0.id == eventID }) { viewModel.select(eventID) }
    }

    /// The footer's button: the submission on Overview, a copy of an ended
    /// event, or sending a draft to App Review on its own.
    private func footerAction(_ viewModel: InAppEventsViewModel) {
        guard let event = viewModel.selectedEvent else { return }
        switch viewModel.status(of: event) {
        case .goesWithVersion: navigator.open(.overview)
        case .ended, .archived: viewModel.duplicateSelectedEvent()
        case .draft, .rejected: confirmsSubmit = true
        case .waitingForReview, .inReview, .approved, .live: break
        }
    }
}
