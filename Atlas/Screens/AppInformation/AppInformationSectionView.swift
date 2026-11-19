//
//  AppInformationSectionView.swift
//  Atlas
//

import SwiftUI

/// The App Information section of an app's workspace (⌘6): one view model
/// per app, kept by the window while other sections show and reloaded by
/// the toolbar's Refresh.
struct AppInformationSectionView: View {
    let app: StoreApp
    let services: any AppInformationServices

    @Environment(ChangeQueue.self) private var queue
    @Environment(AppSummaryStore.self) private var summaries
    @Environment(PushController.self) private var push
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(FieldSuggestionStore.self) private var suggestions
    /// For the team's name on App Compliance; nil in previews and scenes
    /// without a session.
    @Environment(AppSession.self) private var session: AppSession?
    @State private var viewModel: AppInformationViewModel?
    /// The window's kept models; nil in previews without the main window.
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?

    var body: some View {
        Group {
            if let viewModel = shownModel, viewModel.app.id == app.id {
                AppInformationContentView(viewModel: viewModel)
            } else {
                AppInformationPageSkeleton()
                    .padding(Spacing.xxLarge)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.appInformation")
        .task(id: app.id) { await open() }
        .onChange(of: navigator.refreshCount) {
            Task {
                if let viewModel { await load(viewModel) }
            }
        }
        .onChange(of: navigator.intent) { handleIntent() }
    }

    /// Opens the page another part of the window asked for.
    private func handleIntent() {
        guard let viewModel, let intent = navigator.intent else { return }
        if viewModel.handle(intent) { navigator.consume(intent) }
    }

    /// The kept model before `open()` has run, so a section read ahead (or
    /// opened before) shows its content from the first frame, not a
    /// skeleton.
    private var shownModel: AppInformationViewModel? {
        viewModel ?? sectionModels?.keptModels(for: app.id)?.appInformation.flatMap { $0.isLoaded ? $0 : nil }
    }

    private func open() async {
        let kept = sectionModels?.models(for: app.id)
        // Read ahead in the background: show what that read found.
        await kept?.finishWarming(.appInformation)
        guard !Task.isCancelled else { return }
        if let model = kept?.appInformation, model.isLoaded {
            viewModel = model
            handleIntent()
            if kept?.needsLoad(.appInformation, refreshCount: navigator.refreshCount) == true { await load(model) }
            return
        }
        let model = AppInformationViewModel(app: app, services: services, queue: queue, suggestions: suggestions, summaries: summaries, push: push)
        model.sellerName = session?.currentKeyID.flatMap { session?.teamNames[$0] }
        kept?.appInformation = model
        viewModel = model
        handleIntent()
        await load(model)
        #if DEBUG
        if let opening = (services as? DebugAppInformationServices)?.opening {
            await opening.run(on: model)
        }
        #endif
    }

    /// Reads the pages and notes when, so the kept model isn't read again
    /// until Refresh, a push or its age asks for it.
    private func load(_ model: AppInformationViewModel) async {
        await Self.read(model, into: sectionModels?.models(for: app.id), refreshCount: navigator.refreshCount)
    }

    /// Reads the pages and stamps `kept` when it worked, under the Refresh
    /// count the read started with.
    static func read(_ model: AppInformationViewModel, into kept: AppSectionModels?, refreshCount: Int) async {
        await model.load()
        guard !Task.isCancelled, model.isLoaded, model.errorMessage == nil else { return }
        kept?.didLoad(.appInformation, refreshCount: refreshCount)
    }
}
