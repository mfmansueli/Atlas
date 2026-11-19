//
//  ProductPagesSectionView.swift
//  Atlas
//

import SwiftUI

/// The Product Pages section of an app's workspace (⌘4): builds the view
/// model over the shared store and Review & Push's queue (the window
/// keeps it while other sections show), and reads the app's custom
/// product pages when it never did, or what it read is old.
struct ProductPagesSectionView: View {
    let app: StoreApp
    let services: any ProductPagesServices

    @State private var viewModel: ProductPagesViewModel?
    @Environment(ProductPagesStore.self) private var store
    @Environment(ChangeQueue.self) private var queue
    @Environment(WorkspaceNavigator.self) private var navigator
    /// The window's kept models; nil in previews without the main window.
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?

    var body: some View {
        Group {
            if let viewModel = shownModel, viewModel.app.id == app.id {
                ProductPagesScreen(viewModel: viewModel)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.productPages")
        .task(id: app.id) { await start() }
        .onChange(of: navigator.refreshCount) {
            Task {
                if let viewModel { await load(viewModel) }
            }
        }
    }

    /// The kept model before `start()` has run, so a section read ahead (or
    /// opened before) shows its content from the first frame, not a
    /// skeleton.
    private var shownModel: ProductPagesViewModel? {
        viewModel ?? sectionModels?.keptModels(for: app.id)?.productPages
    }

    private func start() async {
        let kept = sectionModels?.models(for: app.id)
        // Read ahead in the background: show what that read found.
        await kept?.finishWarming(.productPages)
        guard !Task.isCancelled else { return }
        let model = kept?.productPages ?? ProductPagesViewModel(app: app, services: services, store: store, queue: queue)
        kept?.productPages = model
        viewModel = model
        if kept?.needsLoad(.productPages, refreshCount: navigator.refreshCount) ?? true { await load(model) }
    }

    private func load(_ model: ProductPagesViewModel) async {
        await Self.read(model, into: sectionModels?.models(for: app.id), refreshCount: navigator.refreshCount)
    }

    /// Reads the pages (again, once they were read) and stamps `kept` when
    /// it worked, under the Refresh count the read started with.
    static func read(_ model: ProductPagesViewModel, into kept: AppSectionModels?, refreshCount: Int) async {
        await model.load(force: model.state.value != nil)
        guard !Task.isCancelled, model.state.value != nil, model.readFailure == nil else { return }
        kept?.didLoad(.productPages, refreshCount: refreshCount)
    }
}
