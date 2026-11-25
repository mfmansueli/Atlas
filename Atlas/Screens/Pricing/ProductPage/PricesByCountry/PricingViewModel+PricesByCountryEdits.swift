//
//  PricingViewModel+PricesByCountryEdits.swift
//  Atlas
//

import Foundation

// Changes made in Prices by Country. Each one loads Apple's price points
// for its countries first when needed, then waits in Review & Push, one row
// per product, with a toast that can take it back. Nothing is pushed.
extension PricingViewModel {
    /// The popover's Set or Use Automatic Price.
    func setCountryPrice(_ edit: CountryPriceEdit, productID: String, territoryID: String, source: ChangeSource = .you) async {
        pricesByCountry.popover = nil
        guard let row = countryRow(productID: productID, territoryID: territoryID) else { return }
        let text = switch edit {
        case .automatic:
            String(localized: "\(row.territory.name): Apple’s automatic price is in Review & Push.", comment: "kind:toast")
        case let .price(price):
            String(localized: "\(row.territory.name): \(row.currency.format(price)) is in Review & Push.", comment: "kind:toast")
        }
        await change(productID: productID, edits: [territoryID: edit], source: source, toast: text)
    }

    /// A row's Accept: that country's suggested price.
    func acceptCountrySuggestion(productID: String, territoryID: String) async {
        guard let row = countryRow(productID: productID, territoryID: territoryID), let suggestion = row.suggestion else { return }
        let text = String(localized: "\(row.territory.name): \(row.currency.format(suggestion.customerPrice)) is in Review & Push.", comment: "kind:toast")
        await change(productID: productID, edits: [territoryID: .price(suggestion.customerPrice)], source: .suggestion, toast: text)
    }

    /// Accept All N…'s Add to Review & Push: the product's schedule first,
    /// so every queued change carries its `startDate` and
    /// `preserveCurrentPrice`, then every open suggestion.
    func acceptAllCountrySuggestions(productID: String, schedule: PriceSchedule) async {
        pricesByCountry.isAcceptAllPresented = false
        if countriesCanSchedule(productID: productID), let matrix = countriesMatrix(productID: productID) {
            matrix.setSchedule(schedule)
        }
        await acceptPriceSuggestion(productID: productID)
    }

    /// What Accept All N… is about to add.
    func acceptAllPlan(productID: String) -> AcceptAllPricesPlan {
        AcceptAllPricesPlan(rows: countryRows(productID: productID) ?? [])
    }

    /// A row's Dismiss: that country's suggestion goes until Restore Dismissed.
    func dismissCountrySuggestion(productID: String, territoryID: String) {
        modes.dismissCountrySuggestion(territoryID: territoryID, productID: productID, appID: app.id)
        pricesByCountry.selection.remove(territoryID)
    }

    /// The bottom bar's Accept N Suggested.
    func acceptCountrySuggestions(productID: String, territoryIDs: Set<Territory.ID>) async {
        let rows = (countryRows(productID: productID) ?? []).filter { territoryIDs.contains($0.id) && $0.hasSuggestion }
        guard !rows.isEmpty else { return }
        var edits: [String: CountryPriceEdit] = [:]
        for row in rows {
            if let suggestion = row.suggestion { edits[row.id] = .price(suggestion.customerPrice) }
        }
        let text = rows.count == 1
            ? String(localized: "1 suggested price is in Review & Push.", comment: "kind:toast")
            : String(localized: "\(rows.count) suggested prices are in Review & Push.", comment: "kind:toast")
        await change(productID: productID, edits: edits, source: .suggestion, toast: text)
        pricesByCountry.selection = []
    }

    /// The bottom bar's Set N to Automatic: the selected countries whose
    /// price someone chose go back to Apple's automatic price.
    func setCountriesToAutomatic(productID: String, territoryIDs: Set<Territory.ID>) async {
        let rows = (countryRows(productID: productID) ?? []).filter { territoryIDs.contains($0.id) && Self.canGoAutomatic($0) }
        guard !rows.isEmpty else { return }
        let text = rows.count == 1
            ? String(localized: "Apple’s automatic price for 1 country is in Review & Push.", comment: "kind:toast")
            : String(localized: "Apple’s automatic price for \(rows.count) countries is in Review & Push.", comment: "kind:toast")
        await change(productID: productID, edits: Dictionary(uniqueKeysWithValues: rows.map { ($0.id, .automatic) }), source: .you, toast: text)
        pricesByCountry.selection = []
    }

    /// Set N to Automatic counts these: a price someone chose, not the base.
    static func canGoAutomatic(_ row: CountryPriceRow) -> Bool {
        !row.isBase && row.source.isChosen
    }

    /// A row's Undo: the country goes back to today's price.
    func undoCountryChange(productID: String, territoryID: String) {
        guard let matrix = countriesMatrix(productID: productID) else { return }
        let product = matrix.product
        if product.isInAppPurchase {
            let id = InAppPurchaseCountryPrices.changeID(productID: productID)
            guard let queued = queue.change(id: id) else { return }
            var edits = InAppPurchaseCountryPrices.edits(of: queued)
            edits[territoryID] = nil
            writeInAppPurchase(edits, matrix: matrix, source: queued.source)
        } else {
            queue.discard(id: PriceChangeFactory.changeID(productID: productID, territoryID: territoryID))
            PricesByCountryChanges.refreshSummary(in: queue, appID: app.id, product: product)
        }
        countriesQueueDidChange(matrix)
    }

    // MARK: - Writing

    /// Writes the edits, then shows the toast with Undo, which puts the
    /// product's queued changes back as they were.
    private func change(productID: String, edits: [String: CountryPriceEdit], source: ChangeSource, toast text: String) async {
        guard let matrix = countriesMatrix(productID: productID) else { return }
        let before = queue.changes(for: app.id, section: .subscriptionPricing).filter { ownsCountryChange($0, productID: productID) }
        guard await matrix.ensureLadders(for: Array(edits.keys)) else { return }
        write(edits, matrix: matrix, source: source)
        let after = queue.changes(for: app.id, section: .subscriptionPricing).filter { ownsCountryChange($0, productID: productID) }
        guard after != before else { return }
        toastUndo = { [weak self] in
            guard let self else { return }
            queue.discardAll { self.ownsCountryChange($0, productID: productID) }
            queue.upsert(contentsOf: before)
            countriesQueueDidChange(matrix)
        }
        toast = ToastMessage(text: text, canUndo: true, actionTitle: String(localized: "Review & Push", comment: "kind:button"))
    }

    /// Writes edits for one product, without a toast (and the MCP tool).
    func write(_ edits: [String: CountryPriceEdit], matrix: PriceMatrixModel, source: ChangeSource) {
        if matrix.product.isInAppPurchase {
            let id = InAppPurchaseCountryPrices.changeID(productID: matrix.product.id)
            var all = queue.change(id: id).map { InAppPurchaseCountryPrices.edits(of: $0) } ?? [:]
            let builder = InAppPurchaseCountryPrices(appID: app.id, product: matrix.product, sheet: matrix.sheet)
            for (territoryID, edit) in edits {
                all[territoryID] = builder.isToday(edit, territoryID: territoryID) ? nil : edit
            }
            writeInAppPurchase(all, matrix: matrix, source: source)
        } else {
            writeSubscription(edits, matrix: matrix, source: source)
        }
        countriesQueueDidChange(matrix)
    }

    /// One `POST /v1/subscriptionPrices` per country; today's price drops
    /// the country's change instead.
    private func writeSubscription(_ edits: [String: CountryPriceEdit], matrix: PriceMatrixModel, source: ChangeSource) {
        let product = matrix.product
        let factory = PriceChangeFactory(appID: app.id, product: product, schedule: matrix.schedule)
        var upserts: [PendingChange] = []
        var discards: [PendingChange.ID] = []
        for (territoryID, edit) in edits {
            guard let row = matrix.row(id: territoryID), let price = matrix.sheet.prices[territoryID] else { continue }
            let point: PricePoint? = switch edit {
            case .automatic: price.equalized
            case let .price(value): matrix.ladder(for: row).point(at: value)
            }
            guard let point else { continue }
            if PricingRow.differs(point.customerPrice, row.current.customerPrice) {
                let change = factory.change(for: row.territory, from: row.current, to: point, source: source)
                upserts.append(PricesByCountryChanges.decorated(
                    change,
                    product: product,
                    territory: row.territory,
                    old: row.current.customerPrice,
                    new: point.customerPrice,
                    isAutomatic: !row.isBase && !PricingRow.differs(point.customerPrice, price.equalized.customerPrice)
                ))
            } else if row.queued != nil {
                discards.append(PriceChangeFactory.changeID(productID: product.id, territoryID: territoryID))
            }
        }
        queue.discard(ids: discards)
        queue.upsert(contentsOf: upserts.sorted { $0.title < $1.title })
        PricesByCountryChanges.refreshSummary(in: queue, appID: app.id, product: product)
    }

    /// The purchase's whole price schedule as one change, or none when
    /// every country is back to today's.
    private func writeInAppPurchase(_ edits: [String: CountryPriceEdit], matrix: PriceMatrixModel, source: ChangeSource) {
        let id = InAppPurchaseCountryPrices.changeID(productID: matrix.product.id)
        let builder = InAppPurchaseCountryPrices(appID: app.id, product: matrix.product, sheet: matrix.sheet)
        let ladder = { (territoryID: String) in matrix.row(id: territoryID).map(matrix.ladder(for:)) }
        if let change = builder.change(edits: edits, ladder: ladder, source: source) {
            queue.upsert(change)
        } else {
            queue.discard(id: id)
        }
    }

    /// The product's rows, its card and the selected matrix read the queue again.
    func countriesQueueDidChange(_ matrix: PriceMatrixModel) {
        matrix.queueDidChange()
        productsQueueDidChange()
        self.matrix?.queueDidChange()
    }
}
