//
//  PricingViewModel+DebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

extension PricingViewModel {
    /// Brings a DEBUG scene to its starting state through the same calls a
    /// person's clicks make. Does nothing outside DEBUG scenes.
    /// Scenes made before the product cards open on the matrix, as their
    /// UI tests expect; `showsProducts` opens on the cards.
    func applyDebugOpening(from services: any PricingServices) {
        guard let debug = services as? DebugPricingServices else { return }
        showsProductDetails = !(debug.launch?.showsProducts ?? false)
        if let state = debug.launch?.reviewShots { applyReviewShotsDebugOpening(state) }
        if debug.launch?.hasSampleOffers == true {
            let reader = DebugSubscriptionOffersReader()
            setup.reader = reader
            setup.codeValues = reader
        }
    }

    func applyDebugLaunch(from services: any PricingServices) async {
        guard let launch = (services as? DebugPricingServices)?.launch else { return }
        if let today = launch.today { self.today = { today } }
        if let productID = launch.productID { await select(productID: productID) }
        applyDebugStrategy(launch)
        if let matrix {
            await applyDebugEdits(launch, to: matrix)
        }
        await applyDebugViews(launch)
        if launch.showsImport {
            let prices = matrix?.sheet.prices
            strategy.previewImport(text: PricingSampleData.customIndexCSV, fileName: PricingSampleData.customIndexFileName) { territory in
                prices?[territory.id]?.equalizationMultiplier
            }
        }
        if launch.refreshes {
            Task { await reload() }
        }
        if let sheet = launch.sheet { applyDebugSheet(sheet) }
        if let sheet = launch.offerSheet, let product = catalog?.product(id: DebugPricingCatalog.lumenMonthlyID) {
            await setup.load([product])
            open(sheet.route(for: product))
        }
        if let sheet = launch.inAppPurchaseOfferSheet, let purchase = catalog?.product(id: DebugPricingCatalog.lumenLifetimeID) {
            await setup.load([purchase])
            openInAppPurchaseOffer(sheet.route(for: purchase))
        }
        if let state = launch.reviewShots { await applyReviewShotsDebugLaunch(state) }
    }

    private func applyDebugSheet(_ sheet: PricingDebugSheet) {
        switch sheet {
        case .newInAppPurchase:
            setup.isNewInAppPurchaseSheetPresented = true
        case let .introductoryOffer(productID):
            if let product = catalog?.product(id: productID) { openIntroductoryOffer(for: product) }
        case let .reviewScreenshot(productID):
            if let product = catalog?.product(id: productID) { openReviewScreenshot(for: product) }
        }
    }

    private func applyDebugStrategy(_ launch: PricingDebugLaunch) {
        if let strategy = launch.strategy {
            self.strategy.replace(with: strategy)
            strategyDidChange()
        }
        strategy.collapsedSections = launch.collapsedSections
        if let tab = launch.inspectorTab {
            inspectorTab = tab
            isInspectorPresented = true
        }
    }

    /// The tab, view, offer and sheet a scene shows.
    private func applyDebugViews(_ launch: PricingDebugLaunch) async {
        if let display = launch.display { self.display = display }
        hoveredTerritoryID = launch.hoveredTerritory
        if let offerID = launch.offerID {
            await loadOffers()
            selectedOfferID = offerID
        }
        if let tab = launch.tab { self.tab = tab }
        if launch.showsSchedule {
            await loadSubscribers()
            isScheduleSheetPresented = true
        }
    }

    private func applyDebugEdits(_ launch: PricingDebugLaunch, to matrix: PriceMatrixModel) async {
        matrix.filter.region = launch.region
        if launch.follows {
            followedProductIDs.insert(matrix.product.id)
            await matrix.follow()
        }
        if !launch.appliedSuggestions.isEmpty {
            await matrix.applySuggestion(to: launch.appliedSuggestions)
        }
        for (territoryID, price) in launch.manualPrices.sorted(by: { $0.key < $1.key }) {
            await matrix.setPrice(territoryID, to: price)
        }
        if let schedule = launch.schedule { matrix.setSchedule(schedule) }
        matrix.selection = Set(launch.selection)
        matrix.popover = launch.popover
    }
}
#endif
