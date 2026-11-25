//
//  PriceResultsModel.swift
//  Atlas
//

import Foundation
import Observation

/// One product's Results: the last change of its prices (pushed, or read
/// from App Store Connect), each territory compared over the 28 days before
/// and after, and Restore where a pushed price got worse, which queues the
/// old price for review like Activity's Restore Previous Values does.
@MainActor
@Observable
final class PriceResultsModel {
    enum State: Equatable {
        case loading
        /// The product's prices haven't changed since Atlas started keeping
        /// their history.
        case noChanges
        /// The 28 days after the change aren't up yet.
        case tooEarly(changedOn: Date, day: Int, arrivesOn: Date)
        /// The 28 days are up, but Atlas can't read sales to compare.
        case salesUnavailable(changedOn: Date)
        case ready(changedOn: Date)
        case failed(String)
    }

    let appID: StoreApp.ID
    let product: PricingProduct
    private(set) var state = State.loading
    /// Territories with enough data, most-viewed first.
    private(set) var results: [PriceChangeResult] = []
    /// Territories with too few to tell, most-viewed first: they list after
    /// the others, each saying what it's short of (board 76).
    private(set) var tooFewResults: [PriceChangeResult] = []
    /// Totals over those territories, plus how many had too little data.
    private(set) var summary: ResultsSummary?

    @ObservationIgnored private let services: any PricingServices
    @ObservationIgnored private let queue: ChangeQueue
    @ObservationIgnored private let territories: TerritoryCatalog
    /// The compared change per territory; pushed ones keep their change, for Restore.
    @ObservationIgnored private var entries: [String: PriceResultsEntry] = [:]

    init(appID: StoreApp.ID, product: PricingProduct, services: any PricingServices, queue: ChangeQueue, territories: TerritoryCatalog = .standard) {
        self.appID = appID
        self.product = product
        self.services = services
        self.queue = queue
        self.territories = territories
    }

    /// Finds the product's last price change in `records` (pushes) and
    /// the price history, and compares, or says when results arrive.
    func load(records: [PushRecord], today: Date) async {
        let history = services.priceHistory(for: product)
        guard let latest = PriceResultsChanges.latest(
            product: product, appID: appID, records: records, history: history, territories: territories
        ), !latest.entries.isEmpty else {
            state = .noChanges
            return
        }
        entries = latest.entries
        switch ResultsEvaluator.availability(changedOn: latest.date, now: today) {
        case let .tooEarly(day, arrivesOn):
            state = .tooEarly(changedOn: latest.date, day: day, arrivesOn: arrivesOn)
        case .ready:
            await compare(changedOn: latest.date)
        }
    }

    /// The table's rows: the territories with a verdict, then the ones with
    /// too few to tell.
    var tableResults: [PriceChangeResult] {
        results + tooFewResults
    }

    // MARK: - Restore

    /// Worse territories whose pushed old price can be put back.
    func canRestore(_ result: PriceChangeResult) -> Bool {
        result.verdict.offersRestore && entries[result.id]?.pushed?.restoreRequests.isEmpty == false
    }

    /// Whether the old price already waits in Review & Push.
    func isRestoreQueued(_ territoryID: String) -> Bool {
        guard let change = entries[territoryID]?.pushed else { return false }
        return queue.change(id: change.id)?.source == .restore
    }

    /// Queues the territory's old price for review. Restores apply as soon
    /// as Apple processes them.
    func restore(_ territoryID: String) {
        guard var change = entries[territoryID]?.pushed?.restoring() else { return }
        change.groupNote = PriceSchedule.immediate.note
        queue.upsert(change)
    }

    // MARK: - Private

    private func compare(changedOn date: Date) async {
        state = .loading
        do {
            let ids = entries.keys.sorted()
            guard let sales = try await services.salesComparison(for: product, territoryIDs: ids, changedOn: date) else {
                state = .salesUnavailable(changedOn: date)
                return
            }
            let all = ids.compactMap { id in entries[id].flatMap { result(for: $0, sales: sales[id]) } }
            summary = ResultsEvaluator.summarize(all)
            results = all.filter(\.verdict.hasEnoughData).sorted { $0.before.pageViews > $1.before.pageViews }
            tooFewResults = all.filter { !$0.verdict.hasEnoughData }.sorted { $0.before.pageViews > $1.before.pageViews }
            state = .ready(changedOn: date)
        } catch {
            state = .failed(AppleErrorCopy(String(localized: "Results didn’t load.", comment: "kind:error"), error: error).text)
        }
    }

    /// A change read back as before and after; a territory without sales
    /// counts as too few to tell.
    private func result(for entry: PriceResultsEntry, sales: SalesComparison?) -> PriceChangeResult? {
        guard let territory = territories.territory(alpha3: entry.territoryID) else { return nil }
        let empty = SalesWindow(pageViews: 0, starts: 0, proceeds: 0)
        return PriceChangeResult(
            territory: territory, oldPrice: entry.oldPrice, newPrice: entry.newPrice, before: sales?.before ?? empty, after: sales?.after ?? empty
        )
    }
}
