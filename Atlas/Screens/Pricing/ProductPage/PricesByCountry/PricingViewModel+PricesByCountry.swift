//
//  PricingViewModel+PricesByCountry.swift
//  Atlas
//

import Foundation

// A product's Prices by Country tab (board 73) reads the product's matrix,
// the one its card uses: every country's price, how it's set, what waits in
// Review & Push and the open suggestion. Edits are in
// `PricingViewModel+PricesByCountryEdits`.
extension PricingViewModel {
    /// The product's matrix: its card's, else the selected product's.
    func countriesMatrix(productID: String) -> PriceMatrixModel? {
        if let matrix = productMatrices[productID] { return matrix }
        return matrix?.product.id == productID ? matrix : nil
    }

    func countriesProduct(productID: String) -> PricingProduct? {
        catalog?.product(id: productID) ?? countriesMatrix(productID: productID)?.product
    }

    /// Every country's row, in catalog order; nil while the prices load.
    func countryRows(productID: String) -> [CountryPriceRow]? {
        guard let matrix = countriesMatrix(productID: productID) else { return nil }
        let product = matrix.product
        let isOpen = card(for: product)?.suggestion != nil
        return CountryPriceRowBuilder(
            product: product,
            sheet: matrix.sheet,
            rows: matrix.rows,
            showsSuggestions: isOpen && matrix.showsSuggestions,
            knowsSuggestions: matrix.showsSuggestions,
            dismissedTerritoryIDs: modes.dismissedCountries(productID: productID, appID: app.id),
            inAppPurchaseQueued: product.isInAppPurchase ? inAppPurchaseQueued(matrix) : [:],
            priceTestNotes: priceTests.notes(productID: productID, on: today())
        )
        .build()
    }

    func countryRow(productID: String, territoryID: String) -> CountryPriceRow? {
        guard let matrix = countriesMatrix(productID: productID), let row = matrix.row(id: territoryID) else { return nil }
        let product = matrix.product
        return CountryPriceRowBuilder(
            product: product,
            sheet: matrix.sheet,
            rows: [row],
            showsSuggestions: card(for: product)?.suggestion != nil && matrix.showsSuggestions,
            knowsSuggestions: matrix.showsSuggestions,
            dismissedTerritoryIDs: modes.dismissedCountries(productID: productID, appID: app.id),
            inAppPurchaseQueued: product.isInAppPurchase ? inAppPurchaseQueued(matrix) : [:],
            priceTestNotes: priceTests.notes(productID: productID, on: today())
        )
        .build().first
    }

    /// Why the prices didn't load, if they didn't.
    func countriesError(productID: String) -> String? {
        productErrors[productID] ?? (selectedProductID == productID ? sheetError : nil)
    }

    /// The product's open suggestion, for the banner above the table.
    func countriesSuggestion(productID: String) -> PricingProductCard.Suggestion? {
        countriesProduct(productID: productID).flatMap(card(for:))?.suggestion
    }

    /// The line under the table.
    func countriesTotals(productID: String) -> PricesByCountryTotals? {
        guard let rows = countryRows(productID: productID), let matrix = countriesMatrix(productID: productID) else { return nil }
        return PricesByCountryTotals(rows: rows, showsSuggestions: matrix.showsSuggestions)
    }

    /// The histogram of what the rows the filters keep cost.
    func countriesHistogram(productID: String, rows: [CountryPriceRow]) -> CountryPriceHistogram {
        let sheet = countriesMatrix(productID: productID)?.sheet
        let currency = sheet.flatMap { TerritoryCatalog.standard.territory(alpha3: $0.baseTerritoryID)?.currencyCode } ?? "USD"
        return CountryPriceHistogram(rows: rows, basePrice: sheet?.basePrice, baseCurrency: currency)
    }

    /// The reference country's short name for "1.1× the US price".
    func countriesBaseName(productID: String) -> String {
        countriesMatrix(productID: productID)?.baseRow?.territory.referenceName ?? "US"
    }

    /// Whether the product's price changes can start on a date (a
    /// subscription's `startDate`); an in-app purchase's change now.
    func countriesCanSchedule(productID: String) -> Bool {
        countriesProduct(productID: productID)?.isInAppPurchase == false
    }

    /// When the product's queued price changes start.
    func countriesSchedule(productID: String) -> PriceSchedule {
        countriesMatrix(productID: productID)?.schedule ?? .immediate
    }

    /// Price changes start: Right Away, keeping whether existing
    /// subscribers keep their price.
    func startCountryChangesRightAway(productID: String) {
        guard let matrix = countriesMatrix(productID: productID) else { return }
        var schedule = matrix.schedule
        schedule.startDay = nil
        matrix.setSchedule(schedule)
    }

    /// Price changes start: On a Date…, the schedule sheet for this product.
    func scheduleCountryChanges(productID: String) {
        guard selectedProductID == productID else { return }
        openSchedule()
    }

    // MARK: - Price points

    /// Whether Apple's own price points for the territory are here, so the
    /// popover can list them.
    func hasCountryPricePoints(productID: String, territoryID: String) -> Bool {
        countriesMatrix(productID: productID)?.sheet.exactLadderIDs.contains(territoryID) ?? false
    }

    /// The territory's price points, lowest first.
    func countryPricePoints(productID: String, territoryID: String) -> [PricePoint] {
        guard let matrix = countriesMatrix(productID: productID), let row = matrix.row(id: territoryID) else { return [] }
        return matrix.ladder(for: row).points
    }

    /// Reads Apple's price points for the territory (`subscriptionPricePoints`
    /// or `inAppPurchasePricePoints`) when they aren't here yet.
    func loadCountryPricePoints(productID: String, territoryID: String) async {
        guard let matrix = countriesMatrix(productID: productID) else { return }
        _ = await matrix.ensureLadders(for: [territoryID])
    }

    // MARK: - Queue

    /// The changes Prices by Country writes for a product: a subscription's
    /// one per country, an in-app purchase's one schedule.
    func ownsCountryChange(_ change: PendingChange, productID: String) -> Bool {
        guard change.appID == app.id, change.section == .subscriptionPricing else { return false }
        return change.id.hasPrefix(PriceChangeFactory.changeID(productID: productID, territoryID: ""))
            || change.id == InAppPurchaseCountryPrices.changeID(productID: productID)
    }

    /// An in-app purchase's queued prices, by territory.
    func inAppPurchaseQueued(_ matrix: PriceMatrixModel) -> [String: QueuedCountryPrice] {
        guard let change = queue.change(id: InAppPurchaseCountryPrices.changeID(productID: matrix.product.id)) else { return [:] }
        return InAppPurchaseCountryPrices.queuedPrices(of: change, sheet: matrix.sheet)
    }
}
