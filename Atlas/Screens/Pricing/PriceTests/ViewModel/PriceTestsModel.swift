//
//  PriceTestsModel.swift
//  Atlas
//

import Foundation
import Observation

/// Pricing's price tests for one app (board 76): the tests and the
/// assistant's suggested tests from `PriceTestStore`, and which of the
/// Test a Price, End Test and Keep Test Prices sheets is open. What the
/// tests do to prices goes through `PricingViewModel+PriceTests`.
@MainActor
@Observable
final class PriceTestsModel {
    let appID: StoreApp.ID
    /// The Test a Price sheet; nil when closed.
    var setup: PriceTestSetup?
    /// End Test Early… or End Test and Set…; nil when closed.
    var ending: PriceTestEnding?
    /// Keep Test Prices…'s test; nil when closed.
    var keepingTestID: PriceTest.ID?
    /// Tests whose Details are open in Results.
    var expandedTestIDs: Set<PriceTest.ID> = []
    #if DEBUG
    /// DEBUG scenes: each country's 28 days, in place of the sheet's.
    var debugSignals: [String: SalesSignal]?
    #endif

    @ObservationIgnored let store: PriceTestStore
    @ObservationIgnored let queue: ChangeQueue

    init(appID: StoreApp.ID, queue: ChangeQueue, store: PriceTestStore? = nil) {
        self.appID = appID
        self.queue = queue
        self.store = store ?? .shared
    }

    // MARK: - Tests

    /// Every test of the app; a queued test whose item left Review & Push
    /// is gone.
    var tests: [PriceTest] {
        store.book(for: appID).tests.filter { test in
            test.state != .queued || queue.change(id: PriceTestChanges.changeID(.start, testID: test.id)) != nil
        }
    }

    func test(id: PriceTest.ID) -> PriceTest? {
        tests.first { $0.id == id }
    }

    /// Results' cards: the product's tests not yet Done, newest first.
    func shownTests(productID: String, on today: Date) -> [PriceTest] {
        tests.filter { $0.productID == productID && $0.phase(on: today) != .done && $0.phase(on: today) != .ended }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// The product's test whose prices are live today.
    func liveTest(productID: String, on today: Date) -> PriceTest? {
        tests.first { $0.productID == productID && $0.isLive(on: today) }
    }

    /// The test still queued or running for the product, if any.
    func activeTests(productID: String, on today: Date) -> [PriceTest] {
        tests.filter { $0.productID == productID && $0.isActive(on: today) }
    }

    /// Verdicts that arrived and weren't read: the sidebar's +1 each.
    func readyCount(on today: Date) -> Int {
        tests.count { if case .ready = $0.phase(on: today) { true } else { false } }
    }

    /// The product pill's tooltip, while a test is queued or running.
    func pillTip(productID: String, on today: Date) -> String? {
        guard let test = activeTests(productID: productID, on: today).first else { return nil }
        return PriceTestText.pillTip(test, today: today)
    }

    /// Prices by Country's notes: the live test's countries, and its
    /// comparison region's.
    func notes(productID: String, on today: Date, catalog: TerritoryCatalog = .standard) -> [String: CountryPriceTestNote] {
        guard let test = liveTest(productID: productID, on: today), let endsOn = test.endsOn else { return [:] }
        var notes: [String: CountryPriceTestNote] = [:]
        if let control = test.control {
            for territory in catalog.territories(in: control) {
                notes[territory.id] = CountryPriceTestNote(
                    role: .comparison, testID: test.id, regionTitle: test.region.title, comparisonTitle: control.title,
                    endsOn: endsOn, countryCount: test.countries.count
                )
            }
        }
        for country in test.countries {
            notes[country.territoryID] = CountryPriceTestNote(
                role: .test, testID: test.id, regionTitle: test.region.title, comparisonTitle: test.control?.title,
                endsOn: endsOn, countryCount: test.countries.count, oldPrice: country.oldPrice
            )
        }
        return notes
    }

    /// Whether the test's ending already waits in Review & Push.
    func isEndQueued(_ test: PriceTest) -> Bool {
        queue.change(id: PriceTestChanges.changeID(.end, testID: test.id)) != nil
    }

    // MARK: - Assistant

    func suggestions(productID: String) -> [PriceTestSuggestion] {
        store.book(for: appID).suggestions.filter { $0.productID == productID }
    }

    func dismissSuggestion(_ id: PriceTestSuggestion.ID) {
        store.update(appID) { $0.suggestions.removeAll { $0.id == id } }
    }

    // MARK: - Decisions

    /// Done on a result: the card goes, and so does the sidebar's +1.
    func markDone(_ testID: PriceTest.ID) {
        store.update(appID) { book in
            guard var test = book.test(id: testID) else { return }
            test.state = .done
            book.replace(test)
        }
        expandedTestIDs.remove(testID)
    }

    func toggleDetails(_ testID: PriceTest.ID) {
        if expandedTestIDs.contains(testID) { expandedTestIDs.remove(testID) } else { expandedTestIDs.insert(testID) }
    }
}
