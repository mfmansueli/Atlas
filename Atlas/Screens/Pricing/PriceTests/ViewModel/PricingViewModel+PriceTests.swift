//
//  PricingViewModel+PriceTests.swift
//  Atlas
//

import Foundation

// Price tests (board 76): Test a Price… opens one sheet from Results or
// the strategy pop-up; Add to Review & Push queues the test price and its
// return on day 28 as one item. While it runs, the test's countries
// suggest nothing; once it ends, Keep Test Prices… queues them again as
// a price change. Nothing is pushed from here.
extension PricingViewModel {
    // MARK: - Opening

    /// Test a Price…, filled in from the assistant's card or Test Again.
    func openPriceTest(productID: String, region: TerritoryRegion? = nil, step: PriceTestStep = .percent(-20), suggestion: PriceTestSuggestion? = nil) {
        var setup = PriceTestSetup(productID: productID, region: region, step: step)
        setup.suggestionID = suggestion?.id
        setup.suggestedBy = suggestion?.source
        if region == nil {
            // The first region with enough people, else the first one.
            let options = priceTestPlanner(productID: productID)?.options() ?? []
            setup.region = (options.first { $0.isAvailable && $0.isEnough } ?? options.first { $0.isAvailable })?.region
        }
        priceTests.setup = setup
    }

    /// Set Up Test… on the assistant's card.
    func openPriceTest(from suggestion: PriceTestSuggestion) {
        openPriceTest(productID: suggestion.productID, region: suggestion.region, step: suggestion.step, suggestion: suggestion)
    }

    /// Test Again…: the same region, a smaller step.
    func testAgain(_ test: PriceTest) {
        priceTests.markDone(test.id)
        openPriceTest(productID: test.productID, region: test.region, step: test.step.smaller)
    }

    // MARK: - Plan

    /// The sheet's countries, from the product's prices: every country but
    /// the base one, with Apple's points and the last 28 days.
    func priceTestPlanner(productID: String) -> PriceTestPlanner? {
        guard let matrix = countriesMatrix(productID: productID) else { return nil }
        let sales = matrix.sheet.sales
        let candidates = matrix.rows.filter { !$0.isBase }.map { row in
            let suggested = row.usesCustomStrategy ? row.calculation.price : row.recommendation?.price
            return PriceTestCandidate(
                territory: row.territory,
                current: row.current,
                ladder: matrix.ladder(for: row),
                suggested: matrix.showsSuggestions && row.hasRealGrid ? suggested : nil,
                recent: recentSignal(row.id, sales: sales)
            )
        }
        return PriceTestPlanner(
            productID: productID,
            productName: matrix.product.name,
            candidates: candidates,
            tests: priceTests.tests,
            today: today()
        )
    }

    /// The open sheet's plan.
    var priceTestPlan: PriceTestPlan? {
        guard let setup = priceTests.setup else { return nil }
        return priceTestPlanner(productID: setup.productID)?.plan(setup)
    }

    /// Apple's price points for the region's countries, so test prices
    /// round to real points.
    func loadPriceTestPoints(productID: String, region: TerritoryRegion) async {
        guard let matrix = countriesMatrix(productID: productID) else { return }
        let ids = matrix.rows.filter { !$0.isBase && $0.territory.region == region }.map(\.id)
        _ = await matrix.ensureLadders(for: ids)
    }

    // MARK: - Queue

    /// The confirmation's Add to Review & Push: the test price and the old
    /// prices on day 28, one item.
    func queuePriceTest() async {
        guard let setup = priceTests.setup, let region = setup.region else { return }
        await loadPriceTestPoints(productID: setup.productID, region: region)
        guard let plan = priceTestPlanner(productID: setup.productID)?.plan(setup), plan.canContinue else { return }
        let id = "pt-\(UUID().uuidString.prefix(8).lowercased())"
        let test = plan.test(id: id, createdAt: .now, suggestedBy: setup.suggestedBy)
        priceTests.store.update(app.id) { book in
            book.replace(test)
            if let suggestionID = setup.suggestionID { book.suggestions.removeAll { $0.id == suggestionID } }
        }
        let source: ChangeSource = setup.suggestedBy.map { .assistant(client: $0) } ?? .you
        queue.upsert(PriceTestChanges.start(test, appID: app.id, source: source))
        priceTests.setup = nil
        productsQueueDidChange()
        toastUndo = { [weak self] in self?.removePriceTest(test.id) }
        toast = ToastMessage(
            text: String(localized: "The \(region.title) price test is in Review & Push. Nothing is sent yet.", comment: "kind:toast"),
            canUndo: true,
            actionTitle: String(localized: "Review & Push", comment: "kind:button")
        )
    }

    /// Remove on a queued test's card (and the toast's Undo).
    func removePriceTest(_ testID: PriceTest.ID) {
        queue.discard(id: PriceTestChanges.changeID(.start, testID: testID))
        priceTests.store.update(app.id) { book in
            book.tests.removeAll { $0.id == testID && $0.state == .queued }
        }
        productsQueueDidChange()
    }

    // MARK: - Ending

    /// End Test Early… on the card's menu.
    func askToEndPriceTest(_ test: PriceTest) {
        priceTests.ending = PriceTestEnding(testID: test.id)
    }

    /// A new price in a country of a running test: End Test and Set….
    func askToEndPriceTest(productID: String, territoryID: String, price: Decimal) {
        pricesByCountry.popover = nil
        guard let test = priceTests.liveTest(productID: productID, on: today()), test.territoryIDs.contains(territoryID) else { return }
        priceTests.ending = PriceTestEnding(testID: test.id, territoryID: territoryID, price: price)
    }

    /// The end sheet's End Test: the old prices now (and the new price in
    /// that country), waiting in Review & Push. Ending gives no result.
    func endPriceTest() async {
        guard let ending = priceTests.ending, let test = priceTests.test(id: ending.testID) else { return }
        var pointID: String?
        if let territoryID = ending.territoryID, let price = ending.price, let matrix = countriesMatrix(productID: test.productID) {
            _ = await matrix.ensureLadders(for: [territoryID])
            pointID = matrix.row(id: territoryID).flatMap { matrix.ladder(for: $0).point(at: price)?.appStoreConnectID }
            // The country's own price change would undo the test's
            // ending: the end item carries the new price instead.
            queue.discard(id: PriceChangeFactory.changeID(productID: test.productID, territoryID: territoryID))
        }
        queue.upsert(PriceTestChanges.end(test, ending: ending, pricePointID: pointID, appID: app.id))
        priceTests.ending = nil
        productsQueueDidChange()
        toast = ToastMessage(
            text: String(localized: "Ending the \(test.region.title) price test is in Review & Push.", comment: "kind:toast"),
            actionTitle: String(localized: "Review & Push", comment: "kind:button")
        )
    }

    // MARK: - Keep

    /// Keep Test Prices…'s Add to Review & Push: the test prices again, as
    /// Prices by Country's changes, so Results compares them like any
    /// price change.
    func keepTestPrices() async {
        guard let id = priceTests.keepingTestID, let test = priceTests.test(id: id),
              let matrix = countriesMatrix(productID: test.productID) else { return }
        priceTests.keepingTestID = nil
        let ids = test.countries.map(\.territoryID)
        guard await matrix.ensureLadders(for: ids) else { return }
        let edits = Dictionary(uniqueKeysWithValues: test.countries.map { ($0.territoryID, CountryPriceEdit.price($0.testPrice)) })
        write(edits, matrix: matrix, source: .you)
        priceTests.store.update(app.id) { book in
            guard var kept = book.test(id: id) else { return }
            kept.state = .kept
            book.replace(kept)
        }
        toast = ToastMessage(
            text: String(localized: "The \(test.region.title) test prices are in Review & Push.", comment: "kind:toast"),
            actionTitle: String(localized: "Review & Push", comment: "kind:button")
        )
    }

    // MARK: - Showing

    /// Show Countries: Prices by Country on the test's region.
    func showPriceTestCountries(_ test: PriceTest) {
        pricesByCountry.filters.regions = [test.region]
        openProduct(test.productID, tab: .pricesByCountry)
    }

    /// Prices by Country's Show Test: the product's Results.
    func showPriceTest(productID: String) {
        openProduct(productID, tab: .results)
    }

    /// "Europe price test · day 9 of 28 · ends Dec 23, then the old
    /// prices come back", over Prices by Country while a test runs.
    func priceTestStatusLine(productID: String) -> String? {
        let now = today()
        guard let test = priceTests.liveTest(productID: productID, on: now), let endsOn = test.endsOn else { return nil }
        return String(
            localized: "\(test.title) · day \(test.day(on: now)) of \(PriceTest.days) · ends \(PriceTestText.shortDate(endsOn)), then the old prices come back",
            comment: "kind:status"
        )
    }

    /// Accept All's line: "Europe is in a price test until Dec 23: its 14
    /// suggested prices are left out."
    func priceTestAcceptAllLine(productID: String) -> String? {
        guard let test = priceTests.liveTest(productID: productID, on: today()), let endsOn = test.endsOn,
              let matrix = countriesMatrix(productID: productID) else { return nil }
        let held = matrix.rows.count(where: \.isHeldBackByPriceTest)
        guard held > 0 else { return nil }
        return String(
            localized: "\(test.region.title) is in a price test until \(PriceTestText.shortDate(endsOn)): its \(held) suggested prices are left out.",
            comment: "kind:sheet-body"
        )
    }

    /// Each matrix leaves its product's live test out of its suggestions.
    func applyPriceTests() {
        let now = today()
        let all = [matrix].compactMap(\.self) + Array(productMatrices.values)
        for matrix in all {
            matrix.priceTestTerritories = priceTests.liveTest(productID: matrix.product.id, on: now)?.territoryIDs ?? []
        }
    }

    // MARK: - Private

    /// The country's last 28 days; without them, its 90 days scaled to 28.
    private func recentSignal(_ territoryID: String, sales: PricingSalesData) -> SalesSignal? {
        #if DEBUG
        if let debug = priceTests.debugSignals { return debug[territoryID] }
        #endif
        if let recent = sales.recentSignals[territoryID] { return recent }
        guard let signal = sales.signals[territoryID] else { return nil }
        let share = { (value: Int) in value * PricingSalesData.recentWindowDays / PricingSalesData.windowDays }
        return SalesSignal(
            pageViews: share(signal.pageViews),
            starts: share(signal.starts),
            proceeds: signal.proceeds * Decimal(PricingSalesData.recentWindowDays) / Decimal(PricingSalesData.windowDays)
        )
    }
}
