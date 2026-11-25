//
//  PricingViewModel.swift
//  Atlas
//

import Foundation
import Observation

/// The Subscription Pricing section of one app: the catalog and selected
/// product, the pricing mode, the strategy inspector, the matrix of the
/// selected product and its other views (map, histogram, schedule, offers
/// and results).
@MainActor
@Observable
final class PricingViewModel {
    let app: StoreApp
    let strategy: PricingStrategyModel
    private(set) var catalogState: LoadState<PricingCatalog> = .idle
    private(set) var selectedProductID: String?
    private(set) var matrix: PriceMatrixModel?
    private(set) var isLoadingSheet = false
    private(set) var sheetError: String?

    var isModeSheetPresented = false
    /// Customize Suggestions…: the strategy inspector.
    var isInspectorPresented = false
    /// Asks before Keep my prices drops the queued price changes.
    var isKeepConfirmationPresented = false

    /// Prices, or Retention.
    var page = PricingPage.prices
    var isScheduleSheetPresented = false
    /// Create Subscription, from the empty state or the product browser.
    var isNewSubscriptionSheetPresented = false
    /// The product whose recommendations Review… shows (a new subscription
    /// added with Review Later), or nil.
    var reviewLaterProductID: String?
    /// The selected subscription has no price yet, so Pricing offers Set
    /// Starting Price instead of a failure.
    private(set) var needsStartingPrice = false
    /// The selected in-app purchase has no price: not a failure, so no
    /// error banner and no Try Again.
    private(set) var hasNoPrice = false
    var isStartingPriceSheetPresented = false
    /// Create In-App Purchase, Add Introductory Offer… and Review
    /// Screenshot…, with what each product has beside its prices.
    let setup = PricingPurchaseSetup()
    /// A product's Prices by Country tab: find, Filters, columns, sort,
    /// selection, the view and the open price popover
    /// (`PricingViewModel+PricesByCountry`).
    let pricesByCountry = PricesByCountryState()
    /// Price tests and their sheets (board 76, `PricingViewModel+PriceTests`).
    let priceTests: PriceTestsModel
    /// Existing subscribers per territory for the schedule's warning; nil
    /// until loaded, or when Atlas can't read them.
    private(set) var subscribers: [String: Int]?
    @ObservationIgnored private var subscribersProductID: String?
    private(set) var offers: LoadState<[SubscriptionOffer]> = .idle
    var selectedOfferID: SubscriptionOffer.ID?
    private(set) var results: PriceResultsModel?

    // MARK: - Product cards

    /// Every product's matrix, for the cards; filled in one product at a
    /// time after the catalog loads.
    var productMatrices: [String: PriceMatrixModel] = [:]
    /// Products whose prices couldn't load, with why.
    var productErrors: [String: String] = [:]
    /// Products whose prices Apple's server failed to send: their card
    /// offers Try Again (`PricingReadFailure`).
    var unreadProductIDs: Set<String> = []
    /// Every product's prices have been read (or failed).
    var areProductsLoaded = false
    /// The product page open in place of the cards (board 73), or nil
    /// (`PricingViewModel+ProductPage`).
    var productRoute: PricingProductRoute?
    /// Each product's availability and Family Sharing, for its Details tab.
    let productFacts = PricingProductFactsStore()
    /// "Preview in"'s country (alpha-3).
    var previewTerritoryID = "USA"
    /// "Preview in"'s country menu is open.
    var isPreviewMenuPresented = false
    /// After Accept: "Prices for Annual accepted. They’re waiting in Review & Push, top right."
    var toast: ToastMessage?
    @ObservationIgnored var toastUndo: (() -> Void)?
    @ObservationIgnored var productsTask: Task<Void, Never>?
    /// Set while the section is read ahead off screen: Apple's price points
    /// are then read only while the hourly quota leaves room. Nil on
    /// screen, where they're always read (`PricingViewModel+PriceGrid`).
    @ObservationIgnored var gridReadAhead: PricingGridReadAhead?
    /// The app's own price and availability, the cards above the products;
    /// nil where the section has no services for them (tests).
    var appPriceAvailability: AppPriceAvailabilityModel?

    /// Today, for Results' 28 days; DEBUG scenes pin it.
    var today: () -> Date = { .now }
    /// The app's finished pushes (`PushHistory`), for Results.
    var pushRecords: () -> [PushRecord] = { [] }

    /// Shows a workspace banner (offline, rate limited, API error).
    var onNotice: (PushNotice) -> Void = { _ in }
    /// Opens Review & Push.
    var onOpenReview: () -> Void = {}

    @ObservationIgnored let queue: ChangeQueue
    @ObservationIgnored let services: any PricingServices
    @ObservationIgnored let modes: PricingModeStore
    @ObservationIgnored var followedProductIDs: Set<String> = []
    /// Counts `load()`s, so one that answers after a newer one started
    /// (Apple took 12 s to fail it) doesn't replace what the newer read.
    @ObservationIgnored private var loadGeneration = 0

    init(app: StoreApp, services: any PricingServices, queue: ChangeQueue, modes: PricingModeStore, commission: Commission) {
        self.app = app
        self.services = services
        self.queue = queue
        self.modes = modes
        priceTests = PriceTestsModel(appID: app.id, queue: queue)
        // The app's own strategy (Customize…), else Settings → Pricing's.
        strategy = PricingStrategyModel(snapshot: services.indexSnapshot(), commission: commission, strategy: modes.strategy(for: app.id))
    }

    // MARK: - Reading

    var mode: PricingMode { modes.mode(for: app.id) }

    var catalog: PricingCatalog? { catalogState.value }

    var selectedProduct: PricingProduct? {
        selectedProductID.flatMap { catalog?.product(id: $0) }
    }

    /// Price changes waiting in Review & Push; new products, their offers
    /// and review screenshots, and retention aren't.
    var pendingPriceChangeCount: Int {
        queue.changes(for: app.id, section: .subscriptionPricing).count { Self.isPriceChange($0) }
    }

    /// A subscription or in-app purchase price change: not a new
    /// subscription, in-app purchase, offer or review screenshot, retention,
    /// or the app's own price and availability.
    static func isPriceChange(_ change: PendingChange) -> Bool {
        !NewSubscriptionChangeBuilder.owns(change) && !PurchaseSetupQueue.isSetup(change) && !RetentionChangeBuilder.owns(change)
            && !AppPriceChangeBuilder.owns(change) && !AppAvailabilityChangeBuilder.owns(change)
    }

    // MARK: - Loading

    /// Loads the catalog and the default product, and asks for a pricing
    /// mode the first time.
    func load() async {
        if modes.chosenMode(for: app.id) == nil { isModeSheetPresented = true }
        loadGeneration += 1
        let generation = loadGeneration
        catalogState = .loading
        await forgetPushedLadders()
        do {
            let catalog = try await services.catalog(for: app)
            guard generation == loadGeneration else { return }
            catalogState = .loaded(catalog)
            let productID = selectedProductID.flatMap { catalog.product(id: $0)?.id } ?? catalog.defaultProduct?.id
            if let productID { await select(productID: productID, force: true) }
            startLoadingProducts()
        } catch {
            guard generation == loadGeneration else { return }
            catalogState = .failed(AppleErrorCopy(String(localized: "Products didn’t load.", comment: "kind:error"), error: error).text)
            reportLoadError(error)
        }
    }

    /// ⌘R and after a push: everything again from App Store Connect.
    func reload() async {
        setup.forget()
        productFacts.forget()
        await load()
    }

    /// The banner for a failed read, if it deserves one (a cancelled read
    /// doesn't).
    func reportLoadError(_ error: any Error) {
        if let notice = PricingLoadNotice.notice(for: error) { onNotice(notice) }
    }

    func select(productID: String, force: Bool = false) async {
        guard force || productID != selectedProductID, let product = catalog?.product(id: productID) else { return }
        selectedProductID = productID
        resetProductViews(for: product)
        isLoadingSheet = true
        sheetError = nil
        needsStartingPrice = false
        hasNoPrice = false
        if matrix?.product.id != productID { matrix = nil }
        defer { isLoadingSheet = false }
        do {
            let sheet = try await services.priceSheet(for: product, commission: strategy.commission)
            guard selectedProductID == productID else { return }
            matrix = makeMatrix(product: product, sheet: sheet)
        } catch {
            guard selectedProductID == productID else { return }
            // Apple's server failing on this product is said on it, not in
            // a banner: the other products' prices are fine.
            let isProductFailure = PricingReadFailure.isProductFailure(error)
            // Atlas's own reasons (no price yet) keep their sentence.
            sheetError = if isProductFailure {
                PricingReadFailure.text(productName: product.name)
            } else if error is PricingSheetError {
                error.localizedDescription
            } else {
                AppleErrorCopy(String(localized: "Prices didn’t load.", comment: "kind:error"), error: error).text
            }
            needsStartingPrice = (error as? PricingSheetError)?.offersStartingPrice == true
            hasNoPrice = error is PricingSheetError && !needsStartingPrice
            if !(error is PricingSheetError), !isProductFailure { reportLoadError(error) }
        }
    }

    /// The selected product's own read failed and its card's read (made
    /// after it) worked: its prices show that read.
    func recoverSelectedPrices(of product: PricingProduct, sheet: ProductPriceSheet) {
        guard selectedProductID == product.id, sheetError != nil, !needsStartingPrice, !hasNoPrice, !isLoadingSheet else { return }
        matrix = makeMatrix(product: product, sheet: sheet)
        sheetError = nil
    }

    /// A matrix for `product` with the current strategy, mode and queue.
    func makeMatrix(product: PricingProduct, sheet: ProductPriceSheet) -> PriceMatrixModel {
        let matrix = PriceMatrixModel(
            appID: app.id,
            product: product,
            sheet: sheet,
            services: services,
            queue: queue,
            strategy: strategy.strategy,
            calculator: strategy.calculator,
            mode: mode,
            isFollowing: followedProductIDs.contains(product.id)
        )
        matrix.onError = { [weak self] error in self?.reportLoadError(error) }
        matrix.priceTestTerritories = priceTests.liveTest(productID: product.id, on: today())?.territoryIDs ?? []
        return matrix
    }

    /// Offers, results and subscribers belong to one product (an in-app
    /// purchase's offers are its offer codes).
    private func resetProductViews(for _: PricingProduct) {
        offers = .idle
        selectedOfferID = nil
        results = nil
        subscribers = nil
        subscribersProductID = nil
    }

    func setCommission(_ commission: Commission) async {
        guard commission != strategy.commission else { return }
        strategy.setCommission(commission)
        if let productID = selectedProductID { await select(productID: productID, force: true) }
        startLoadingProducts()
    }

    // MARK: - Mode

    /// The first-visit sheet's Continue.
    func choose(_ mode: PricingMode) async {
        isModeSheetPresented = false
        await setMode(mode)
    }

    /// The first-visit sheet's Not Now: keep the default for now and ask again next time.
    func notNow() {
        isModeSheetPresented = false
    }

    func setMode(_ mode: PricingMode) async {
        if mode == .keepPrices, pendingPriceChangeCount > 0 {
            isKeepConfirmationPresented = true
            return
        }
        apply(mode: mode)
        if mode == .applyRecommended { await applyRecommendedPrices() }
    }

    /// Keep my prices after confirming: queued price changes go (new
    /// products, their setup and retention stay).
    func confirmKeepPrices() {
        queue.discardAll {
            $0.appID == app.id && $0.section == .subscriptionPricing && Self.isPriceChange($0)
        }
        apply(mode: .keepPrices)
        matrix?.queueDidChange()
        productsQueueDidChange()
    }

    /// The keep bottom bar's “Show price suggestions”.
    func showPriceSuggestions() {
        apply(mode: .showSuggestions)
    }

    func apply(mode: PricingMode) {
        modes.setMode(mode, for: app.id)
        if mode == .keepPrices {
            followedProductIDs = []
            isInspectorPresented = false
        }
        matrix?.update(mode: mode)
        for matrix in productMatrices.values { matrix.update(mode: mode) }
    }

    /// Fills every territory with its proposal, then opens Review & Push.
    func applyRecommendedPrices() async {
        guard let matrix, !matrix.isReadOnly else { return }
        followedProductIDs.insert(matrix.product.id)
        await matrix.follow()
        onOpenReview()
    }

    // MARK: - Strategy

    func toggleInspector() {
        isInspectorPresented.toggle()
    }

    /// Edits the strategy; the matrix updates live, and followed proposals follow.
    func editStrategy(_ change: (inout PricingStrategy) -> Void) {
        strategy.edit(change)
        strategyDidChange()
    }

    func resetStrategy() {
        strategy.resetToRecommended()
        strategyDidChange()
    }

    func toggleExclusion(of territoryID: String) {
        strategy.toggleExclusion(of: territoryID)
        strategyDidChange()
    }

    func confirmImport() {
        strategy.confirmImport()
        strategyDidChange()
    }

    func strategyDidChange() {
        // Kept per app, so Pricing opens on it again and the price tools
        // over MCP suggest from it; Settings' defaults stay the app's until
        // it differs from them.
        if modes.hasOwnStrategy(app.id) || strategy.strategy != modes.defaultStrategy {
            modes.setStrategy(strategy.strategy, for: app.id)
        }
        matrix?.update(strategy: strategy.strategy, calculator: strategy.calculator)
        for matrix in productMatrices.values { matrix.update(strategy: strategy.strategy, calculator: strategy.calculator) }
    }

    // MARK: - Schedule

    /// The bottom bar's “Starts now”, or Review & Push's “Edit…”.
    func openSchedule() {
        isScheduleSheetPresented = true
        Task { await loadSubscribers() }
    }

    func loadSubscribers() async {
        guard let product = selectedProduct, subscribersProductID != product.id else { return }
        subscribersProductID = product.id
        let counts = try? await services.subscribers(for: product)
        guard selectedProductID == product.id else { return }
        subscribers = counts
    }

    /// The schedule sheet's Save.
    func saveSchedule(_ schedule: PriceSchedule) {
        matrix?.setSchedule(schedule)
        isScheduleSheetPresented = false
    }

    // MARK: - Offers and Results

    /// Reads the selected subscription's offers once, selecting the first
    /// promotional offer (else the first); an in-app purchase's, its offer
    /// codes.
    func loadOffers() async {
        guard let product = selectedProduct, !offers.isLoading, offers.value == nil else { return }
        offers = .loading
        if product.isInAppPurchase {
            let list = await readInAppPurchaseOffers(for: product)
            guard selectedProductID == product.id else { return }
            offers = .loaded(list)
            if selectedOfferID == nil { selectedOfferID = list.first?.id }
            return
        }
        do {
            var list = try await services.offers(for: product)
            // Pricing's services don't read introductory offers from App
            // Store Connect; the push's transport does.
            if !list.contains(where: { $0.kind == .introductory }) { list += await readIntroductoryOffers(for: product) }
            // Promotional, win-back and offer code offers come with the
            // extras the push's transport read.
            let known = Set(list.map(\.id))
            list += existingSubscriptionOffers(for: product).filter { !known.contains($0.id) }
            guard selectedProductID == product.id else { return }
            offers = .loaded(list)
            if selectedOfferID == nil { selectedOfferID = (list.first { $0.kind == .promotional } ?? list.first)?.id }
        } catch {
            guard selectedProductID == product.id else { return }
            offers = .failed(AppleErrorCopy(String(localized: "Offers didn’t load.", comment: "kind:error"), error: error).text)
        }
    }

    var selectedOffer: SubscriptionOffer? {
        offers.value?.first { $0.id == selectedOfferID }
    }

    /// Compares the selected product's last price push, once per product
    /// (and again after `resultsDidChange()`).
    func loadResults() async {
        guard let product = selectedProduct, results?.product.id != product.id else { return }
        let model = PriceResultsModel(appID: app.id, product: product, services: services, queue: queue)
        results = model
        await model.load(records: pushRecords(), today: today())
    }

    /// A push finished: Results compare again when shown.
    func resultsDidChange() {
        results = nil
    }
}
