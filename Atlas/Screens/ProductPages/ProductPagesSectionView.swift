//
//  ProductPagesSectionView.swift
//  Atlas
//

import SwiftUI

/// The Custom Product Pages section of an app's workspace (⌘4): builds the
/// view model over the shared store and Review & Push's queue (the window
/// keeps it while other sections show), reads the app's custom product
/// pages when it never did or what it read is old, gives it Analytics'
/// numbers, reads them again after a push, and opens the page Analytics or
/// the Overview asks for.
struct ProductPagesSectionView: View {
    let app: StoreApp
    let services: any ProductPagesServices
    /// The app's Screenshots, a page's own set is made from (board 52).
    var screenshots: (any ScreenshotsServices)?

    @State private var viewModel: ProductPagesViewModel?
    @Environment(ProductPagesStore.self) private var store
    @Environment(ChangeQueue.self) private var queue
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(AnalyticsStore.self) private var analytics
    @Environment(PushHistory.self) private var history
    @Environment(PageShotsStudio.self) private var pageShots: PageShotsStudio?
    @Environment(ClaudeCodeLauncher.self) private var launcher: ClaudeCodeLauncher?
    /// The window's kept models; nil in previews without the main window.
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?

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
        .accessibilityIdentifier("workspace.productPages")
        .task(id: app.id) { await start() }
        .onChange(of: navigator.refreshCount) {
            Task {
                if let viewModel {
                    setNumbers(viewModel)
                    await load(viewModel)
                }
            }
        }
        .onChange(of: navigator.intent) { handleIntent() }
        .onChange(of: history.records(for: app.id).count) { didPush() }
    }

    private func content(_ viewModel: ProductPagesViewModel) -> some View {
        ProductPagesScreen(viewModel: viewModel) { navigator.isReviewPresented = true }
            .sheet(
                isPresented: Binding { viewModel.isNewPagePresented } set: { viewModel.isNewPagePresented = $0 },
                onDismiss: { viewModel.newPageTemplate = nil },
                content: {
                    NewProductPageSheet(
                        viewModel: viewModel, page: viewModel.newPageTemplate ?? NewProductPage(locales: [viewModel.primaryLocale])
                    )
                }
            )
            .sheet(isPresented: Binding { viewModel.isSubmitPresented } set: { viewModel.isSubmitPresented = $0 }) {
                if let page = viewModel.selectedPage {
                    ProductPageSubmitSheet(viewModel: viewModel, page: page)
                }
            }
            .sheet(isPresented: pageShotsPresented(viewModel)) {
                if let flow = viewModel.pageShots {
                    PageShotsSheet(flow: flow, defaultSet: { locale, device in
                        viewModel.screenshots(viewModel.defaultScreenshotsKey(locale), device: device)
                    }, viewModel: viewModel)
                        .task { await viewModel.loadScreenshots(of: nil, locale: flow.run?.primaryLocale ?? viewModel.primaryLocale) }
                }
            }
            .alert(
                viewModel.confirmation.map(viewModel.confirmationTitle) ?? "",
                isPresented: Binding { viewModel.confirmation != nil } set: { if !$0 { viewModel.confirmation = nil } },
                presenting: viewModel.confirmation
            ) { confirmation in
                Button(viewModel.confirmationButton(confirmation), role: viewModel.isDestructive(confirmation) ? .destructive : nil) {
                    viewModel.confirm(confirmation)
                }
                .accessibilityIdentifier("pages.confirm")
                Button("Cancel", role: .cancel) { viewModel.confirmation = nil }
            } message: { confirmation in
                Text(viewModel.confirmationMessage(confirmation))
            }
            .overlay(alignment: .bottom) {
                if let toast = viewModel.toast {
                    ActionToast(message: toast) {
                        viewModel.undoLast()
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

    /// The page's screenshot sheet is open: closing it while Autopilot
    /// works hides it, and the run keeps going.
    private func pageShotsPresented(_ viewModel: ProductPagesViewModel) -> Binding<Bool> {
        Binding {
            guard let studio = pageShots, let key = studio.presentedKey, let flow = viewModel.pageShots else { return false }
            return key == flow.key
        } set: { isPresented in
            guard !isPresented, let studio = pageShots, let key = studio.presentedKey else { return }
            if studio.run(key)?.stage.isWorking == true { studio.update(key) { $0.isHidden = true } }
            studio.presentedKey = nil
        }
    }

    /// Make Screenshots for This Page…: a page's flow, starting Claude Code
    /// with the launcher (or copying the prompt).
    private func setUpPageShots(_ model: ProductPagesViewModel) {
        guard let studio = pageShots, let screenshots else { return }
        model.pageShotsStudio = studio
        model.makePageShotsFlow = { [weak model, launcher, app, queue] page in
            let flow = PageShotsFlow(
                app: app, page: page, studio: studio, queue: queue, screenshots: screenshots,
                languages: model?.pageShotsLanguages ?? [app.primaryLocale ?? "en-US"],
                ownLocales: page.locales, note: model?.pageShotsNote(of: page) ?? ""
            )
            flow.launch = { purpose, prompt in
                await launcher?.start(purpose, appID: app.id, appName: app.name, prompt: prompt)
            }
            flow.stopClaude = { id in launcher?.stop(id) }
            flow.copy = { text in EventArtworkFilePanel.copy(text) }
            flow.onToast = { [weak model] message in model?.toast = message }
            #if DEBUG
            PageShotsDebugSetup.pending?.apply(to: flow)
            #endif
            return flow
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
        setUpPageShots(model)
        setNumbers(model)
        #if DEBUG
        let launch = ProductPagesDebugLaunch.pending
        ProductPagesDebugLaunch.pending = nil
        #endif
        if kept?.needsLoad(.productPages, refreshCount: navigator.refreshCount) ?? true { await load(model) }
        #if DEBUG
        launch?.apply(to: model)
        #endif
        handleIntent()
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

    /// The last 28 days by page, from what Analytics has on this Mac.
    private func setNumbers(_ model: ProductPagesViewModel) {
        model.setNumbers(from: analytics.archive(for: app.id).pageFacts)
    }

    /// Analytics' Open Page, or the Overview's card.
    private func handleIntent() {
        guard let viewModel, case let .showProductPage(name) = navigator.intent, viewModel.state.value != nil,
              navigator.requestedAppID.map({ $0 == app.id }) ?? true else { return }
        navigator.consume(.showProductPage(name: name))
        if let name {
            viewModel.openPage(named: name)
        } else {
            viewModel.back()
        }
    }

    /// A push of this app finished: when it had pages in it, they're read
    /// again (a draft has its App Store Connect ID now), and Push and
    /// Submit… goes on to Submit for Review.
    private func didPush() {
        guard let viewModel, let record = history.lastRecord(for: app.id) else { return }
        let builder = viewModel.builder
        let pushedPages = (record.pushed + record.failedChanges).contains { builder.owns($0) }
        guard pushedPages else { return }
        let failures = record.failures.filter { $0.key.hasPrefix(builder.idPrefix) }.map(\.value)
        Task { await viewModel.didPush(failures: failures) }
    }
}
