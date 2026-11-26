//
//  WorkspaceSectionWarmer.swift
//  Atlas
//

import Foundation

/// Reads an app's sections ahead for the main window, with the window's
/// services and stores, making each model the way its section view makes
/// it (and reading it with the views' own `read`), so opening the section
/// finds it loaded. What only the screen needs (intents, sheets, DEBUG
/// openings) stays with the views.
@MainActor
struct WorkspaceSectionWarmer: SectionWarming {
    let services: WorkspaceServices
    let queue: ChangeQueue
    let summaries: AppSummaryStore
    let push: PushController
    let suggestions: FieldSuggestionStore
    let preferences: AppPreferences
    let modes: PricingModeStore
    let navigator: WorkspaceNavigator
    let history: PushHistory
    let reviews: ReviewsStore
    let events: InAppEventsStore
    let productPages: ProductPagesStore
    let analytics: AnalyticsStore
    let artwork: EventArtworkStudio
    /// The team's name, for App Compliance.
    let sellerName: String?
    /// The connected key, for Analytics' setup.
    let keyID: String?
    /// Suggested review replies are Pro.
    let isPro: Bool
    /// The hourly quota last reported, nil when unknown: Pricing reads
    /// Apple's price points ahead only while it leaves room.
    var quota: @Sendable () -> AppStoreConnectRateLimit? = { nil }

    func needsWarming(_ section: AppWorkspaceSection, of app: StoreApp, kept: AppSectionModels, refreshCount: Int) -> Bool {
        switch section {
        // Read when they open, from what's kept on this Mac.
        case .reviews: kept.reviews == nil || reviews.isStale(app.id)
        // A push or Refresh since the last read reads the events again, so
        // their dates and "Before App Review" lists show what it wrote.
        case .inAppEvents: kept.events?.state.value == nil || kept.needsLoad(section, refreshCount: refreshCount)
        // Read when it opens: a few small requests, nothing kept.
        case .nominations: false
        default: kept.needsLoad(section, refreshCount: refreshCount)
        }
    }

    func warm(_ section: AppWorkspaceSection, of app: StoreApp, kept: AppSectionModels, refreshCount: Int) async {
        switch section {
        case .overview:
            _ = await OverviewSectionView.readContent(for: app, services: services.storePage, into: kept, refreshCount: refreshCount)
        case .storePage:
            await warmStorePage(app, kept: kept, refreshCount: refreshCount)
        case .screenshots:
            let model = kept.screenshots ?? ScreenshotsSectionModel(app: app, services: services.storePage, push: push)
            model.takeIcon(app.icon)
            kept.screenshots = model
            await ScreenshotsSectionView.read(model, into: kept, refreshCount: refreshCount, includingSets: true)
        case .productPages:
            let model = kept.productPages ?? ProductPagesViewModel(app: app, services: services.productPages, store: productPages, queue: queue)
            kept.productPages = model
            await ProductPagesSectionView.read(model, into: kept, refreshCount: refreshCount)
        case .inAppEvents:
            let model = kept.events ?? InAppEventsViewModel(app: app, services: services.inAppEvents, store: events, queue: queue)
            kept.events = model
            model.artworkStudio = artwork
            model.pushHistory = history
            let force = model.state.value != nil
            await InAppEventsSectionView.read(model, into: kept, refreshCount: refreshCount, force: force)
            await InAppEventsSectionView.loadResults(model, services: services.inAppEvents)
        case .appInformation:
            await warmAppInformation(app, kept: kept, refreshCount: refreshCount)
        case .subscriptionPricing:
            await warmPricing(app, kept: kept, refreshCount: refreshCount)
        case .reviews:
            let model = kept.reviews ?? ReviewsViewModel(app: app, store: reviews, services: services.reviews)
            kept.reviews = model
            model.isPro = isPro
            await model.load()
        case .analytics:
            let model = kept.analytics ?? AnalyticsViewModel(app: app, store: analytics, services: services.analytics)
            kept.analytics = model
            model.keyID = keyID
            model.recompute()
            // Apple's reports download when Analytics opens, or each
            // morning when the person chose so; only the context is read
            // ahead.
            await AnalyticsSectionView.readContext(model, services: services, into: kept, refreshCount: refreshCount)
        case .nominations:
            break
        }
    }

    /// A kept page that loaded is read again; one that never did is made
    /// anew, as the section does.
    private func warmStorePage(_ app: StoreApp, kept: AppSectionModels, refreshCount: Int) async {
        let model: StorePageViewModel
        if let loaded = kept.storePage, loaded.isLoaded {
            model = loaded
        } else {
            model = StorePageViewModel(app: app, services: services.storePage, queue: queue, suggestions: suggestions, summaries: summaries, push: push)
            model.checksRepeatedWords = preferences.checksRepeatedWords
            kept.storePage = model
        }
        await StorePageSectionView.read(model, into: kept, refreshCount: refreshCount)
    }

    private func warmAppInformation(_ app: StoreApp, kept: AppSectionModels, refreshCount: Int) async {
        let model: AppInformationViewModel
        if let loaded = kept.appInformation, loaded.isLoaded {
            model = loaded
        } else {
            model = AppInformationViewModel(
                app: app, services: services.appInformation, queue: queue, suggestions: suggestions, summaries: summaries, push: push
            )
            model.sellerName = sellerName
            kept.appInformation = model
        }
        await AppInformationSectionView.read(model, into: kept, refreshCount: refreshCount)
    }

    /// Kept prices are read again with Retention, as Refresh does; new
    /// ones are read the first time, Retention when it shows.
    private func warmPricing(_ app: StoreApp, kept: AppSectionModels, refreshCount: Int) async {
        if let model = kept.pricing, let retention = kept.retention, model.catalog != nil {
            model.gridReadAhead = PricingGridReadAhead(quota: quota)
            await PricingSectionView.read(model, retention: retention, into: kept, refreshCount: refreshCount)
            return
        }
        let model = PricingViewModel(
            app: app, services: services.pricing, queue: queue, modes: modes, commission: Commission(preferenceRate: preferences.commissionRate)
        )
        let retention = RetentionModel(app: app, services: services.retention, queue: queue)
        PricingSectionView.connect(model, retention: retention, push: push, navigator: navigator, history: history)
        PricingSectionView.attachAppPriceAvailability(to: model, services: services.appPriceAvailability, queue: queue, navigator: navigator)
        kept.pricing = model
        kept.retention = retention
        model.gridReadAhead = PricingGridReadAhead(quota: quota)
        await PricingSectionView.read(model, retention: nil, into: kept, refreshCount: refreshCount)
    }
}
