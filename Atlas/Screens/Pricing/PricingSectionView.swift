//
//  PricingSectionView.swift
//  Atlas
//

import SwiftUI

/// The Subscription Pricing section of an app's workspace (⌘7): builds the
/// view model from the window's queue, modes and preferences, and connects
/// it to Refresh, workspace intents, Review & Push and the push history
/// Results read.
struct PricingSectionView: View {
    let app: StoreApp
    let services: any PricingServices
    let retention: any RetentionServices
    /// The app's own price and where it's sold.
    let appPriceAvailability: any AppPriceAvailabilityServices

    @State private var viewModel: PricingViewModel?
    @State private var retentionModel: RetentionModel?
    /// The window's kept models; nil in previews without the main window.
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?
    @Environment(ChangeQueue.self) private var changes
    @Environment(PricingModeStore.self) private var modes
    @Environment(AppPreferences.self) private var preferences
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(PushController.self) private var push
    @Environment(PushHistory.self) private var history
    @Environment(AppSummaryStore.self) private var summaries
    @Environment(AnalyticsStore.self) private var analytics: AnalyticsStore?

    var body: some View {
        Group {
            if let viewModel = shownModel, viewModel.page == .retention, let retentionModel = shownRetention {
                RetentionScreen(
                    model: retentionModel, pricing: viewModel,
                    saveRates: analytics.flatMap { RetentionReport.make($0.reports(for: retentionModel.app.id), days: 28) }
                ) {
                    navigator.openAnalytics(.subscriptions, pane: .retention, appID: retentionModel.app.id)
                }
            } else if let viewModel = shownModel {
                PricingScreen(viewModel: viewModel, defaultMode: preferences.defaultPricingMode)
            } else {
                PricingTableSkeleton(columns: PriceColumnPreset.automatic.columns)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.subscriptionPricing")
        .task { await start() }
        .onChange(of: navigator.refreshCount) {
            Task {
                await reload()
                await handlePendingIntent()
            }
        }
        .onChange(of: navigator.intent) {
            Task { await handlePendingIntent() }
        }
        .onChange(of: preferences.commissionRate) { _, rate in
            Task { await viewModel?.setCommission(Commission(preferenceRate: rate)) }
        }
        .onChange(of: changes.changes(for: app.id, section: .subscriptionPricing)) { queueDidChange() }
        // The tab bar's and Overview's Pricing count, once every product's
        // prices are read.
        .onChange(of: suggestionCount, initial: true) { _, count in
            if let count { summaries.setPricingSuggestionCount(count, for: app.id) }
        }
        .onChange(of: history.records.count) {
            viewModel?.resultsDidChange()
        }
    }

    private var suggestionCount: Int? {
        guard let viewModel, viewModel.areProductsLoaded else { return nil }
        return viewModel.openPriceSuggestionCount
    }

    /// The kept models before `start()` has run, so prices read ahead (or
    /// opened before) show from the first frame, not a skeleton.
    private var shownModel: PricingViewModel? {
        if let viewModel { return viewModel }
        guard let kept = sectionModels?.keptModels(for: app.id), kept.retention != nil, let model = kept.pricing, model.catalog != nil else { return nil }
        return model
    }

    private var shownRetention: RetentionModel? {
        retentionModel ?? sectionModels?.keptModels(for: app.id)?.retention
    }

    private func start() async {
        guard viewModel == nil else { return }
        let kept = sectionModels?.models(for: app.id)
        // Read ahead in the background: show what that read found.
        await kept?.finishWarming(.subscriptionPricing)
        guard !Task.isCancelled else { return }
        // The window keeps the models while other sections show: the
        // prices are there when the person comes back.
        if let model = kept?.pricing, let retentionModel = kept?.retention, model.catalog != nil {
            self.retentionModel = retentionModel
            Self.attachAppPriceAvailability(to: model, services: appPriceAvailability, queue: changes, navigator: navigator)
            viewModel = model
            // What changed while another section showed.
            queueDidChange()
            model.resultsDidChange()
            await model.setCommission(Commission(preferenceRate: preferences.commissionRate))
            if kept?.needsLoad(.subscriptionPricing, refreshCount: navigator.refreshCount) == true { await reload() }
            await handlePendingIntent()
            return
        }
        let model = PricingViewModel(
            app: app,
            services: services,
            queue: changes,
            modes: modes,
            commission: Commission(preferenceRate: preferences.commissionRate)
        )
        let retentionModel = RetentionModel(app: app, services: retention, queue: changes)
        Self.connect(model, retention: retentionModel, push: push, navigator: navigator, history: history)
        Self.attachAppPriceAvailability(to: model, services: appPriceAvailability, queue: changes, navigator: navigator)
        #if DEBUG
        model.applyDebugOpening(from: services)
        #endif
        self.retentionModel = retentionModel
        viewModel = model
        kept?.pricing = model
        kept?.retention = retentionModel
        await Self.read(model, retention: nil, into: kept, refreshCount: navigator.refreshCount)
        #if DEBUG
        await model.applyDebugLaunch(from: services)
        await retentionModel.applyDebugLaunch(from: retention, pricing: model)
        model.appPriceAvailability?.applyDebugLaunch(from: appPriceAvailability)
        #endif
        await handlePendingIntent()
    }

    /// Lays the queue back onto the prices, the cards and Retention.
    private func queueDidChange() {
        viewModel?.matrix?.queueDidChange()
        viewModel?.productsQueueDidChange()
        retentionModel?.refresh()
    }

    /// ⌘R, after a push, or kept prices that got old: everything again.
    private func reload() async {
        guard let viewModel else { return }
        await Self.read(viewModel, retention: retentionModel, into: sectionModels?.models(for: app.id), refreshCount: navigator.refreshCount)
    }

    /// Connects new models to the window, as opening the section or
    /// reading it ahead makes them: a failed read's banner, Review & Push,
    /// and the push history Results reads.
    static func connect(_ model: PricingViewModel, retention: RetentionModel, push: PushController, navigator: WorkspaceNavigator, history: PushHistory) {
        let appID = model.app.id
        model.onNotice = { [push] notice in push.report(notice) }
        model.onOpenReview = { [navigator] in navigator.isReviewPresented = true }
        model.pushRecords = { [history] in history.records(for: appID) }
        model.setup.transport = { [weak push] in push?.transport }
        retention.onOpenReview = { [navigator] in navigator.isReviewPresented = true }
    }

    /// Gives a model made without them (read ahead, or kept from before)
    /// the app's price and availability cards, connected to Review & Push.
    static func attachAppPriceAvailability(
        to model: PricingViewModel,
        services: any AppPriceAvailabilityServices,
        queue: ChangeQueue,
        navigator: WorkspaceNavigator
    ) {
        guard model.appPriceAvailability == nil else { return }
        let appModel = AppPriceAvailabilityModel(app: model.app, services: services, queue: queue)
        appModel.onOpenReview = { [navigator] in navigator.isReviewPresented = true }
        model.appPriceAvailability = appModel
        // Kept prices were read without them.
        if model.catalog != nil { Task { await appModel.load() } }
    }

    /// Reads the catalog and the default product's prices: the first time
    /// (`retention` nil, Retention reads itself when it shows), or again
    /// with Retention's messages and offers. Stamps `kept` once the catalog
    /// is read, so the kept model isn't read again until Refresh, a push
    /// or its age asks for it.
    static func read(_ model: PricingViewModel, retention: RetentionModel?, into kept: AppSectionModels?, refreshCount: Int) async {
        if let retention {
            await model.reload()
            if let catalog = model.catalog { await retention.load(subscriptions: RetentionSubscription.all(in: catalog)) }
        } else {
            await model.load()
        }
        await model.appPriceAvailability?.load()
        guard !Task.isCancelled, model.catalog != nil else { return }
        kept?.didLoad(.subscriptionPricing, refreshCount: refreshCount)
    }

    /// Handles the navigator's intent once prices are here, so “Apply
    /// Recommended Prices…” from the overview has a matrix to fill.
    private func handlePendingIntent() async {
        guard let viewModel, let intent = navigator.intent, viewModel.catalog != nil, !viewModel.isLoadingSheet else { return }
        if await viewModel.handle(intent) { navigator.consume(intent) }
    }
}
