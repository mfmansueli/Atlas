//
//  AnalyticsSectionView.swift
//  Atlas
//

import SwiftUI

/// The Analytics section of an app's workspace (⌘8): builds the view model
/// over the shared store, downloads Apple's reports when today's check
/// hasn't happened, and reads what the other sections know to explain the
/// numbers.
struct AnalyticsSectionView: View {
    let app: StoreApp
    let services: WorkspaceServices
    /// Every app in the library, for the settings sheet.
    let library: [StoreApp.ID]

    @State private var viewModel: AnalyticsViewModel?
    @Environment(AnalyticsStore.self) private var store
    @Environment(AppSummaryStore.self) private var summaries
    @Environment(PushHistory.self) private var history
    @Environment(PushController.self) private var push
    @Environment(ChangeQueue.self) private var changes
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(AppSession.self) private var session: AppSession?
    /// The window's kept models; nil in previews without the main window.
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?

    var body: some View {
        Group {
            if let viewModel {
                AnalyticsScreen(
                    viewModel: viewModel,
                    waitingCount: waitingCount,
                    onReview: { navigator.isReviewPresented = true },
                    onAct: { action, text in
                        navigator.follow(action, origin: AnalyticsOrigin(appID: app.id, text: text, tab: viewModel.tab))
                    }
                )
                .sheet(isPresented: Binding(get: { viewModel.isSettingsPresented }, set: { viewModel.isSettingsPresented = $0 })) {
                    AnalyticsSettingsSheet(
                        store: store,
                        apps: library.map { ($0, push.appName($0)) },
                        focus: viewModel.settingsFocus
                    ) { appID in
                        let message = await store.stop(for: appID, services: services.analytics)
                        viewModel.recompute()
                        return message
                    } onVendorNumberChanged: {
                        Task { await viewModel.vendorNumberChanged() }
                    }
                }
            } else {
                Color.clear
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.analytics")
        .task(id: app.id) { await start() }
        .onChange(of: navigator.refreshCount) {
            Task { await viewModel?.refresh(force: true) }
        }
        .onChange(of: summaries.pricing[app.id]?.value) { configure() }
        .onChange(of: history.records) { configure() }
        .onChange(of: navigator.requestedAnalyticsTab) { takeRequestedTab() }
    }

    private func start() async {
        let kept = sectionModels?.models(for: app.id)
        let model = kept?.analytics ?? AnalyticsViewModel(app: app, store: store, services: services.analytics)
        kept?.analytics = model
        model.keyID = session?.currentKeyID
        model.recompute()
        viewModel = model
        configure()
        takeRequestedTab()
        #if DEBUG
        AnalyticsDebugLaunch.pending?.apply(to: model)
        AnalyticsDebugLaunch.pending = nil
        #endif
        await summaries.load(app)
        configure()
        async let refresh: Void = model.refresh()
        if let fixed = services.analytics.fixedContext {
            model.setContext(fixed)
            await refresh
            return
        }
        let loader = AnalyticsContextLoader(services: services)
        let page = await loader.storePage(for: app)
        model.setContext(page)
        if model.setup == .ready {
            await model.setContext(loader.pricing(for: app, into: page))
        }
        await refresh
    }

    private func configure() {
        // Until Pricing has been read, assume a subscription: most apps
        // here sell one, and the steps say what's missing otherwise.
        let sells = summaries.pricing[app.id]?.value.map { $0.subscriptionCount > 0 } ?? true
        viewModel?.configure(sellsSubscriptions: sells, changes: ChangeLog.changes(for: app.id, in: history.records))
    }

    private func takeRequestedTab() {
        guard let tab = navigator.requestedAnalyticsTab, let viewModel else { return }
        navigator.requestedAnalyticsTab = nil
        if viewModel.tabs.contains(tab) { viewModel.tab = tab }
    }

    private func waitingCount(_ finding: AnalyticsFinding) -> Int {
        changes.changes(for: app.id, section: finding.area.section).count
    }
}
