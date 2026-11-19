//
//  StorePageSectionView.swift
//  Atlas
//

import SwiftUI

/// The Store Page section of an app's workspace (⌘2). It makes the
/// `StorePageViewModel` from the environment's queue, summaries and push
/// controller, once per app (the window keeps it while other sections
/// show, so coming back doesn't read the page again), and keeps it in step
/// with the workspace:
/// Refresh reloads, intents from menus and the overview are handled, and a
/// queue changed elsewhere (Review & Push) is laid back onto the listing.
struct StorePageSectionView: View {
    let app: StoreApp
    let services: any StorePageServices

    @Environment(ChangeQueue.self) private var queue
    @Environment(AppSummaryStore.self) private var summaries
    @Environment(PushController.self) private var push
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(FieldSuggestionStore.self) private var suggestions
    @Environment(AppPreferences.self) private var preferences
    @State private var viewModel: StorePageViewModel?
    /// The window's kept models; nil in previews without the main window.
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?

    var body: some View {
        Group {
            if let viewModel = shownModel, viewModel.app.id == app.id {
                StorePageContentView(viewModel: viewModel)
            } else {
                StorePageSkeleton()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.storePage")
        .task(id: app.id) { await open() }
        .onChange(of: navigator.refreshCount) {
            Task {
                if let viewModel { await load(viewModel) }
            }
        }
        .onChange(of: navigator.intent) { handleIntent() }
        .onChange(of: queue.changes) { viewModel?.queueDidChange() }
    }

    /// The kept model before `open()` has run, so a section read ahead (or
    /// opened before) shows its content from the first frame, not a
    /// skeleton.
    private var shownModel: StorePageViewModel? {
        viewModel ?? sectionModels?.keptModels(for: app.id)?.storePage.flatMap { $0.isLoaded ? $0 : nil }
    }

    private func open() async {
        let kept = sectionModels?.models(for: app.id)
        // Read ahead in the background: show what that read found.
        await kept?.finishWarming(.storePage)
        guard !Task.isCancelled else { return }
        if let model = kept?.storePage, model.isLoaded {
            model.checksRepeatedWords = preferences.checksRepeatedWords
            viewModel = model
            // The queue may have changed while another section showed.
            model.queueDidChange()
            handleIntent()
            if kept?.needsLoad(.storePage, refreshCount: navigator.refreshCount) == true { await load(model) }
            return
        }
        let model = StorePageViewModel(app: app, services: services, queue: queue, suggestions: suggestions, summaries: summaries, push: push)
        model.checksRepeatedWords = preferences.checksRepeatedWords
        kept?.storePage = model
        viewModel = model
        handleIntent()
        await load(model)
        #if DEBUG
        if let opening = (services as? DebugStorePageServices)?.opening {
            await opening.run(on: model)
        }
        #endif
    }

    /// Reads the page and notes when, so the kept model isn't read again
    /// until Refresh, a push or its age asks for it.
    private func load(_ model: StorePageViewModel) async {
        await Self.read(model, into: sectionModels?.models(for: app.id), refreshCount: navigator.refreshCount)
    }

    /// Reads the page and stamps `kept` when it worked, under the Refresh
    /// count the read started with.
    static func read(_ model: StorePageViewModel, into kept: AppSectionModels?, refreshCount: Int) async {
        await model.load()
        guard !Task.isCancelled, model.isLoaded, model.errorMessage == nil else { return }
        kept?.didLoad(.storePage, refreshCount: refreshCount)
    }

    /// Takes the Store Page's intents (Translate Missing…, Find and
    /// Replace, Import, Find, Screenshots); the view model runs them once
    /// loaded. An intent for another app waits for that app's page.
    private func handleIntent() {
        guard let intent = navigator.intent, StorePageViewModel.handles(intent), let viewModel,
              navigator.requestedAppID.map({ $0 == app.id }) ?? true else { return }
        viewModel.handle(intent)
        navigator.consume(intent)
    }
}
