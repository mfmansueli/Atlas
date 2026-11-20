//
//  InAppEventsSectionView.swift
//  Atlas
//

import SwiftUI

/// The In-App Events section of an app's workspace (⌘5): builds the view
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
    @Environment(EventArtworkStudio.self) private var artwork
    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(ProGate.self) private var pro: ProGate?
    @Environment(PushHistory.self) private var history: PushHistory?
    @Environment(AppPreferences.self) private var preferences
    /// The window's kept models; nil in previews without the main window.
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?
    /// Where the artwork viewer covers the whole window; nil in previews,
    /// where it covers the section.
    @Environment(WindowCover.self) private var cover: WindowCover?

    var body: some View {
        Group {
            if let viewModel = shownModel, viewModel.app.id == app.id {
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
        .onChange(of: viewModel?.artworkRequest) { handleArtworkRequest() }
        .onChange(of: artwork.presentedKey) { showPresentedArtwork() }
        .onChange(of: pageKey) { pageChanged() }
        .onChange(of: viewModel?.artworkFlow?.viewer != nil) { presentViewer() }
        .onChange(of: runSignature) { old, new in announce(from: old, to: new) }
        .onDisappear {
            artwork.watch(nil)
            viewModel?.artworkFlow?.closeViewer()
            cover?.hide(Self.viewerID)
        }
    }

    private func content(_ viewModel: InAppEventsViewModel) -> some View {
        InAppEventsScreen(viewModel: viewModel, artworkActions: artworkActions(viewModel), onFooterAction: { footerAction(viewModel) })
            .sheet(isPresented: Binding { viewModel.isNewEventPresented } set: { viewModel.isNewEventPresented = $0 }) {
                NewInAppEventSheet(appName: app.name, primaryLocale: app.primaryLocale ?? "en-US") { event in
                    viewModel.problem(for: event)
                } onCancel: {
                    viewModel.isNewEventPresented = false
                } onAdd: { event in
                    let added = viewModel.add(event)
                    if added { viewModel.isNewEventPresented = false }
                    return added
                } warnings: { event in
                    viewModel.warnings(for: event)
                }
            }
            .sheet(isPresented: artworkSheetBinding(viewModel)) {
                if let flow = viewModel.artworkFlow {
                    let size = EventArtworkSheetSize.current
                    EventArtworkSheet(flow: flow, width: size.width, height: size.height) {
                        pro.require(.eventArtwork) { Task { await flow.make() } }
                    }
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
            .overlay {
                // Without the main window (previews), the viewer covers the section.
                if cover == nil, let flow = viewModel.artworkFlow, flow.viewer != nil {
                    EventArtworkFullSizeViewer(flow: flow, viewModel: viewModel)
                }
            }
    }

    /// The version on its way to the App Store, read by the main window.
    private var release: ReleaseViewModel? {
        sectionModels?.models(for: app.id).release
    }

    /// The kept model before `start()` has run, so a section read ahead (or
    /// opened before) shows its content from the first frame, not a
    /// skeleton.
    private var shownModel: InAppEventsViewModel? {
        viewModel ?? sectionModels?.keptModels(for: app.id)?.events
    }

    private func start() async {
        let kept = sectionModels?.models(for: app.id)
        // Read ahead in the background: show what that read found.
        await kept?.finishWarming(.inAppEvents)
        guard !Task.isCancelled else { return }
        let model = kept?.events ?? InAppEventsViewModel(app: app, services: services.inAppEvents, store: store, queue: queue)
        kept?.events = model
        model.artworkStudio = artwork
        model.pushHistory = history
        viewModel = model
        configure()
        #if DEBUG
        let launch = InAppEventsDebugLaunch.pending
        InAppEventsDebugLaunch.pending = nil
        #endif
        // A kept model reads again once a push or Refresh happened since
        // its read (or it's old): its "Before App Review" list and dates
        // then show what the push wrote.
        let force = model.state.value != nil && kept?.needsLoad(.inAppEvents, refreshCount: navigator.refreshCount) == true
        await Self.read(model, into: kept, refreshCount: navigator.refreshCount, force: force)
        #if DEBUG
        launch?.apply(to: model)
        #endif
        handleIntent()
        showPresentedArtwork()
        pageChanged()
        handleArtworkRequest()
        await summaries.load(app)
        configure()
        await Self.loadResults(model, services: services.inAppEvents)
    }

    private func reload() async {
        guard let viewModel else { return }
        await Self.read(viewModel, into: sectionModels?.models(for: app.id), refreshCount: navigator.refreshCount, force: true)
        await Self.loadResults(viewModel, services: services.inAppEvents)
    }

    /// Reads the events (the first time, or again with `force`) and stamps
    /// the kept models when the read worked; the read ahead reads the same
    /// way.
    static func read(_ model: InAppEventsViewModel, into kept: AppSectionModels?, refreshCount: Int, force: Bool = false) async {
        guard await model.load(force: force) else { return }
        kept?.didLoad(.inAppEvents, refreshCount: refreshCount)
    }

    /// Apple's numbers for the events that are over.
    static func loadResults(_ model: InAppEventsViewModel, services: any InAppEventsServices) async {
        for event in model.events where event.state.isOver && model.results[event.id] == nil {
            model.results[event.id] = await services.results(for: event, of: model.app)
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

    /// The Overview's version card opens the event that goes with it; the
    /// Submit sheet's Fix… on a date opens it on its dates.
    private func handleIntent() {
        guard let viewModel, viewModel.state.value != nil, navigator.requestedAppID.map({ $0 == app.id }) ?? true else { return }
        switch navigator.intent {
        case let .showInAppEvents(eventID):
            navigator.consume(.showInAppEvents(eventID: eventID))
            if let eventID, viewModel.events.contains(where: { $0.id == eventID }) { viewModel.open(eventID) }
        case let .showInAppEventDates(eventID, field):
            navigator.consume(.showInAppEventDates(eventID: eventID, field: field))
            guard viewModel.events.contains(where: { $0.id == eventID }) else { return }
            viewModel.open(eventID)
            // Once the page is there, so it scrolls to the dates.
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                viewModel.focusedDateField = field
            }
        default:
            return
        }
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

    // MARK: - Artwork (boards 40 and 47)

    static let viewerID = "events.artwork.viewer"

    /// The event page on screen, if one is.
    private var pageKey: EventArtworkRun.Key? {
        guard let viewModel, viewModel.showsEvent, let id = viewModel.selectedEventID else { return nil }
        return EventArtworkRun.Key(appID: app.id, eventID: id)
    }

    /// An event's page opened, or another: its flow, and its run is seen.
    private func pageChanged() {
        guard let viewModel else { return }
        if viewModel.artworkFlow?.key != pageKey { viewModel.artworkFlow?.closeViewer() }
        if pageKey != nil, let event = viewModel.selectedEvent { _ = artworkFlow(for: event, in: viewModel, fresh: false) }
        artwork.watch(pageKey)
        presentViewer()
    }

    /// The viewer over the whole window while the flow has one open.
    private func presentViewer() {
        guard let cover else { return }
        if let viewModel, let flow = viewModel.artworkFlow, flow.viewer != nil {
            cover.show(Self.viewerID) { EventArtworkFullSizeViewer(flow: flow, viewModel: viewModel) }
        } else {
            cover.hide(Self.viewerID)
        }
    }

    /// What the page's run is at, to say when the concepts are in.
    private var runSignature: String {
        guard let flow = viewModel?.artworkFlow, flow.isStarted else { return "" }
        let run = flow.run
        return "\(flow.event.id)|\(run.step.rawValue)|\(run.revisingID ?? "")|\(run.designedCount)"
    }

    /// "3 concepts are ready…" when the run ends, or "Claude changed
    /// …" when a change arrives.
    private func announce(from old: String, to new: String) {
        guard let viewModel, let flow = viewModel.artworkFlow else { return }
        let before = old.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        let after = new.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard before.count == 4, after.count == 4, before[0] == after[0] else { return }
        let run = flow.run
        if before[1] == EventArtworkStep.making.rawValue, after[1] != EventArtworkStep.making.rawValue, before[2].isEmpty, !run.isAnimating {
            let count = run.designedCount
            guard count > 0 else { return }
            let lead = count == 1 ? String(localized: "1 concept is ready for \(flow.event.referenceName).")
                : String(localized: "\(count) concepts are ready for \(flow.event.referenceName).")
            viewModel.toast = ToastMessage(text: lead + " " + String(localized: "Open one to see it full size."))
        } else if !before[2].isEmpty, after[2].isEmpty, let concept = run.concepts.first(where: { $0.id == before[2] }), concept.revisedAt != nil {
            viewModel.toast = ToastMessage(text: String(localized: "Claude changed “\(concept.name)” the way you asked."))
        }
    }

    /// The Artwork panel's buttons and rows.
    private func artworkActions(_ viewModel: InAppEventsViewModel) -> EventArtworkPanelActions {
        let flow = { viewModel.artworkFlow }
        return EventArtworkPanelActions(
            make: { if let event = viewModel.selectedEvent { viewModel.requestArtwork(.make, for: event) } },
            chooseFiles: { if let event = viewModel.selectedEvent { viewModel.requestArtwork(.chooseFiles, for: event) } },
            stop: { flow()?.stop() },
            view: { id, kind in
                guard let flow = flow() else { return }
                flow.openViewer(conceptID: id ?? flow.previewConcept?.id, kind: kind ?? viewModel.previewKind, locale: viewModel.localeCode)
            },
            preview: { flow()?.preview($0) },
            change: { flow()?.change() },
            keepCurrent: { flow()?.keepCurrent() },
            use: { Task { await flow()?.use() } },
            addMotion: { Task { await flow()?.addMotion() } }
        )
    }

    private func artworkSheetBinding(_ viewModel: InAppEventsViewModel) -> Binding<Bool> {
        Binding {
            guard let flow = viewModel.artworkFlow else { return false }
            return artwork.presentedKey == flow.key
        } set: { isShown in
            guard !isShown, let flow = viewModel.artworkFlow, artwork.presentedKey == flow.key else { return }
            flow.close()
        }
    }

    /// Make the Artwork… behind the Pro gate (the Brief), or Choose
    /// Files…'s open panel.
    private func handleArtworkRequest() {
        guard let viewModel, let request = viewModel.artworkRequest,
              let event = viewModel.events.first(where: { $0.id == request.eventID }) else { return }
        viewModel.artworkRequest = nil
        switch request.action {
        case .make:
            pro.require(.eventArtwork) {
                let flow = artworkFlow(for: event, in: viewModel, fresh: true)
                artwork.presentedKey = flow.key
            }
        case .chooseFiles:
            guard let urls = EventArtworkFilePanel.choose(eventName: event.referenceName), !urls.isEmpty else { return }
            let flow = artworkFlow(for: event, in: viewModel, fresh: false)
            Task { await flow.chooseFiles(urls) }
        }
    }

    /// A Brief opened elsewhere: its event's page, then the sheet.
    private func showPresentedArtwork() {
        guard let viewModel, let key = artwork.presentedKey, key.appID == app.id,
              let event = viewModel.events.first(where: { $0.id == key.eventID }) else { return }
        if !viewModel.showsEvent || viewModel.selectedEventID != event.id { viewModel.open(event.id) }
        if viewModel.artworkFlow?.key != key { _ = artworkFlow(for: event, in: viewModel, fresh: false) }
    }

    /// The event's flow, kept while its page shows; `fresh` starts a new
    /// Brief when no run is going.
    private func artworkFlow(for event: InAppEvent, in viewModel: InAppEventsViewModel, fresh: Bool) -> EventArtworkFlow {
        // Make the Artwork shows only when the event needs art: a run left
        // from before without a used concept gives way to a new Brief.
        if fresh, let run = artwork.run(appID: app.id, eventID: event.id), run.step != .making, run.usedConceptID == nil {
            artwork.remove(run.key)
            if viewModel.artworkFlow?.event.id == event.id { viewModel.artworkFlow = nil }
        }
        if let flow = viewModel.artworkFlow, flow.event.id == event.id { return flow }
        let flow = EventArtworkFlow(
            app: app, event: event, studio: artwork, queue: queue, hasDesignSystem: EventArtworkSheetSize.hasDesignSystem(app.id)
        )
        // Settings → Screenshots: what a new Brief starts with.
        if !flow.isStarted {
            flow.edit { run in
                run.wordsInArt = preferences.eventArtworkHasWords
                run.makesMotion = preferences.eventArtworkMakesMotion
            }
        }
        flow.launch = { [launcher, app] purpose, prompt in
            await launcher.start(purpose, appID: app.id, appName: app.name, prompt: prompt)
        }
        flow.stopClaude = { [launcher] id in launcher.stop(id) }
        flow.copy = { text in EventArtworkFilePanel.copy(text) }
        flow.onToast = { [weak viewModel] message, undo in
            guard let viewModel else { return }
            if let undo { viewModel.undo = undo }
            viewModel.toast = message
        }
        #if DEBUG
        DebugEventArtworkSetup.pending?.apply(to: flow)
        #endif
        viewModel.artworkFlow = flow
        return flow
    }
}
