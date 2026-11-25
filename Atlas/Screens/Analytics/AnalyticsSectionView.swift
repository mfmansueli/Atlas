//
//  AnalyticsSectionView.swift
//  Atlas
//

import SwiftUI

/// The Analytics section of an app's workspace (⌘9): builds the view model
/// over the shared store, downloads Apple's reports when today's check
/// hasn't happened, and reads what the other sections know to explain the
/// numbers (kept with the model, read again after Refresh, a push or when
/// old).
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
            if let viewModel = shownModel {
                AnalyticsScreen(
                    viewModel: viewModel,
                    waitingCount: waitingCount,
                    onAct: { action, text in
                        navigator.follow(action, origin: AnalyticsOrigin(appID: app.id, text: text, tab: viewModel.tab))
                    },
                    stabilityRelease: stabilityRelease
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

    /// The kept model before `start()` has run, so a section read ahead (or
    /// opened before) shows its content from the first frame, not a
    /// skeleton.
    private var shownModel: AnalyticsViewModel? {
        viewModel ?? sectionModels?.keptModels(for: app.id)?.analytics
    }

    private func start() async {
        let kept = sectionModels?.models(for: app.id)
        // Read ahead in the background: show what that read found.
        await kept?.finishWarming(.analytics)
        guard !Task.isCancelled else { return }
        let model = kept?.analytics ?? AnalyticsViewModel(app: app, store: store, services: services.analytics)
        kept?.analytics = model
        model.keyID = session?.currentKeyID
        model.onWrite = { [history] record in history.add(record) }
        model.recompute()
        viewModel = model
        configure()
        takeRequestedTab()
        #if DEBUG
        let launch = AnalyticsDebugLaunch.pending
        launch?.apply(to: model)
        AnalyticsDebugLaunch.pending = nil
        if let action = launch?.follow {
            navigator.follow(action, origin: AnalyticsOrigin(appID: app.id, text: launch?.followText ?? "", tab: model.tab))
        }
        #endif
        await summaries.load(app)
        configure()
        async let refresh: Void = model.refresh()
        if kept?.needsLoad(.analytics, refreshCount: navigator.refreshCount) ?? true {
            await Self.readContext(model, services: services, into: kept, refreshCount: navigator.refreshCount)
        }
        await refresh
    }

    /// Reads what the other sections know into `model` (the store page
    /// first, which is quick, then prices and retention once Analytics is
    /// set up) and stamps `kept`, under the Refresh count the read started
    /// with, once the store page was read: a failed read is tried again
    /// the next time Analytics opens.
    static func readContext(_ model: AnalyticsViewModel, services: WorkspaceServices, into kept: AppSectionModels?, refreshCount: Int) async {
        if let fixed = services.analytics.fixedContext {
            model.setContext(fixed)
            kept?.didLoad(.analytics, refreshCount: refreshCount)
            return
        }
        let loader = AnalyticsContextLoader(services: services)
        let page = await loader.storePage(for: model.app)
        model.setContext(page)
        if model.setup == .ready {
            let priced = await loader.pricing(for: model.app, into: page)
            model.setContext(priced)
            await model.setContext(loader.screenshots(for: model.app, into: priced))
        }
        guard !Task.isCancelled, page != .empty else { return }
        kept?.didLoad(.analytics, refreshCount: refreshCount)
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
        if let pane = navigator.requestedSubscriptionsPane {
            navigator.requestedSubscriptionsPane = nil
            viewModel.subscriptionsPane = pane
        }
        if viewModel.tabs.contains(tab) { viewModel.tab = tab }
    }

    /// The version's card, and Pause Phased Release… while a phased
    /// release of it rolls out (read by the Overview and Release).
    private var stabilityRelease: StabilityReleaseActions {
        let release = sectionModels?.models(for: app.id).release
        return StabilityReleaseActions(
            phase: release?.phase,
            isPausing: release?.busyAction == .pause,
            openVersion: { navigator.openVersion(submitting: false) },
            pause: { Task { await release?.perform(.pause) } }
        )
    }

    private func waitingCount(_ finding: AnalyticsFinding) -> Int {
        changes.changes(for: app.id, section: finding.area.section).count
    }
}
