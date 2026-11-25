//
//  PricingViewModel+PriceTestsDebug.swift
//  Atlas
//

#if DEBUG
import Foundation

extension PricingViewModel {
    /// Puts Lumen Plus Annual's price tests where the scene wants them
    /// (`PriceTestDebugScenes`), built from its own prices, then opens the
    /// scene's sheet. Nothing is pushed.
    func applyPriceTestsDebugLaunch(_ launch: PriceTestDebugLaunch?) async {
        guard let launch else { return }
        priceTests.debugSignals = launch.signals
        let productID = DebugPricingCatalog.lumenAnnualID
        if countriesMatrix(productID: productID) == nil { await select(productID: productID) }
        for region in TerritoryRegion.allCases {
            await loadPriceTestPoints(productID: productID, region: region)
        }
        var book = PriceTestBook()
        if let test = debugTest(for: launch.state, productID: productID) {
            book.tests = [test]
            if test.state == .queued { queue.upsert(PriceTestChanges.start(test, appID: app.id, source: .you, at: DebugPriceTests.today)) }
        }
        if launch.state == .suggested { book.suggestions = [DebugPriceTests.suggestion(productID: productID)] }
        priceTests.store.load(book, for: app.id)
        applyPriceTests()
        productsQueueDidChange()
        openDebugSheet(for: launch.state, productID: productID, test: book.tests.first)
    }

    private func debugTest(for state: PriceTestDebugState, productID: String) -> PriceTest? {
        switch state {
        case .none, .setup, .suggested:
            return nil
        case .queued:
            return debugPlan(productID: productID, step: .percent(-20))?.test(id: "pt-debug", createdAt: DebugPriceTests.today, suggestedBy: nil)
        case .running, .conflict, .stopping:
            // Today's prices are the test's: the old ones were about 20% higher.
            guard let raise = debugPlan(productID: productID, step: .percent(20)) else { return nil }
            var test = raise.test(id: "pt-debug", createdAt: DebugPriceTests.runningStart, suggestedBy: nil)
            test.step = .percent(-20)
            test.keepsTestPrice = true
            test.countries = raise.countries.map { country in
                PriceTestCountry(
                    territoryID: country.territoryID, currencyCode: country.currencyCode, oldPrice: country.testPrice, testPrice: country.oldPrice,
                    oldPricePointID: country.testPricePointID, testPricePointID: country.oldPricePointID
                )
            }
            test.state = .running
            test.startedOn = DebugPriceTests.runningStart
            return test
        case let .ready(verdict, _):
            return finishedTest(productID: productID, verdict: verdict, state: .running)
        case .keeping:
            return finishedTest(productID: productID, verdict: .better, state: .running)
        case .kept:
            return finishedTest(productID: productID, verdict: .better, state: .kept)
        }
    }

    private func finishedTest(productID: String, verdict: ResultVerdict, state: PriceTestState) -> PriceTest? {
        guard var test = debugPlan(productID: productID, step: .percent(-20))?
            .test(id: "pt-debug", createdAt: DebugPriceTests.finishedStart, suggestedBy: nil)
        else { return nil }
        test.state = state
        test.startedOn = DebugPriceTests.finishedStart
        test.windows = DebugPriceTests.windows(verdict)
        return test
    }

    private func debugPlan(productID: String, step: PriceTestStep) -> PriceTestPlan? {
        let setup = PriceTestSetup(productID: productID, region: .europe, step: step)
        return priceTestPlanner(productID: productID)?.plan(setup)
    }

    private func openDebugSheet(for state: PriceTestDebugState, productID: String, test: PriceTest?) {
        switch state {
        case let .setup(region, step, control, confirming):
            var setup = PriceTestSetup(productID: productID, region: region, step: step, control: control)
            setup.isConfirming = confirming
            priceTests.setup = setup
        case .conflict:
            guard let test, let germany = test.country("DEU") else { return }
            priceTests.ending = PriceTestEnding(testID: test.id, territoryID: germany.territoryID, price: germany.oldPrice)
        case .stopping:
            if let test { priceTests.ending = PriceTestEnding(testID: test.id) }
        case .ready(_, details: true):
            if let test { priceTests.expandedTestIDs = [test.id] }
        case .keeping:
            priceTests.keepingTestID = test?.id
        case .none, .queued, .running, .ready, .kept, .suggested:
            break
        }
    }
}
#endif
