//
//  PriceMatrixModel.swift
//  Atlas
//

import Foundation
import Observation

/// The prices of one product in every country: its rows and every edit,
/// each of which becomes a pending change.
/// The change queue is the source of truth for proposed prices.
@MainActor
@Observable
final class PriceMatrixModel {
    let appID: StoreApp.ID
    let product: PricingProduct
    private(set) var sheet: ProductPriceSheet
    private(set) var strategy: PricingStrategy
    private(set) var calculator: PriceCalculator
    private(set) var mode: PricingMode
    private(set) var rows: [PricingRow] = []
    /// Countries (alpha-3) of this product's running price test: their
    /// rows suggest nothing until it ends (board 76).
    var priceTestTerritories: Set<String> = [] {
        didSet { if priceTestTerritories != oldValue { rebuild(recommendations: false) } }
    }

    /// Whether every territory follows the strategy, as after Apply Suggested Prices….
    private(set) var isFollowing: Bool
    /// When the queued changes take effect; read from the queue, so it
    /// survives navigating away.
    private(set) var schedule: PriceSchedule
    /// True while Apple's price points load for an edit.
    private(set) var isLoadingLadders = false
    /// Whether Apple's price points for every territory are here: no
    /// suggestion is built until they are (`loadGrid()`).
    private(set) var grid: PriceGridState
    var onError: (any Error) -> Void = { _ in }

    @ObservationIgnored let queue: ChangeQueue
    @ObservationIgnored private let services: any PricingServices
    @ObservationIgnored private let territories: TerritoryCatalog
    @ObservationIgnored private var recommendations: [String: Recommendation] = [:]
    @ObservationIgnored private var refollowTask: Task<Void, Never>?
    @ObservationIgnored private var gridTask: Task<Void, Never>?

    init(
        appID: StoreApp.ID,
        product: PricingProduct,
        sheet: ProductPriceSheet,
        services: any PricingServices,
        queue: ChangeQueue,
        strategy: PricingStrategy,
        calculator: PriceCalculator,
        mode: PricingMode,
        isFollowing: Bool = false,
        territories: TerritoryCatalog = .standard
    ) {
        self.appID = appID
        self.product = product
        self.sheet = sheet
        self.services = services
        self.queue = queue
        self.strategy = strategy
        self.calculator = calculator
        self.mode = mode
        self.isFollowing = isFollowing
        self.territories = territories
        schedule = PriceSchedule.current(in: queue, appID: appID, productID: product.id)
        grid = PriceGridState.of(sheet)
        rebuild(recommendations: true)
    }

    // MARK: - Reading

    /// Keep my prices and in-app purchases show prices without edits.
    var isReadOnly: Bool { mode == .keepPrices || product.isInAppPurchase }

    var showsSuggestions: Bool { mode.showsSuggestions && !product.isInAppPurchase }

    /// Suggestions would show but Apple's price points aren't all here.
    /// In-app purchases and Keep my prices suggest nothing, so they read
    /// none ahead (a price you choose reads its country's).
    var needsGrid: Bool { showsSuggestions && !grid.isReady }

    /// "Checking Apple's prices…" shows instead of suggestions.
    var isCheckingGrid: Bool { showsSuggestions && grid.isChecking }

    /// Why Apple's price points didn't load, while suggestions would show.
    var gridFailure: String? { showsSuggestions ? grid.failure : nil }

    /// The same, as the error template shows it (the product card's).
    var gridFailureCopy: AppleErrorCopy? { showsSuggestions ? grid.failureCopy : nil }

    /// Rows with a stepper instead of an Apply button.
    func showsStepper(_ row: PricingRow) -> Bool {
        !isReadOnly && (row.queued != nil || isFollowing || mode == .applyRecommended)
    }

    var pendingCount: Int { rows.count { $0.queued != nil } }

    var heldBackCount: Int { rows.count(where: \.likelyHeldBack) }

    var customCount: Int { rows.count(where: \.isCustomPrice) }

    var baseRow: PricingRow? { rows.first(where: \.isBase) }

    func row(id: PricingRow.ID) -> PricingRow? {
        rows.first { $0.id == id }
    }

    func ladder(for row: PricingRow) -> PricePointLadder {
        sheet.ladder(for: row.territory, commission: calculator.commission)
    }

    // MARK: - Updating

    func update(strategy: PricingStrategy, calculator: PriceCalculator) {
        let commissionChanged = calculator.commission != self.calculator.commission
        self.strategy = strategy
        self.calculator = calculator
        rebuild(recommendations: commissionChanged)
        if isFollowing { scheduleRefollow() }
    }

    func update(mode: PricingMode) {
        guard mode != self.mode else { return }
        let suggestionsChanged = mode.showsSuggestions != self.mode.showsSuggestions
        self.mode = mode
        if mode == .keepPrices { isFollowing = false }
        if suggestionsChanged { rebuild(recommendations: true) }
        // The person asked for suggestions: they need Apple's points.
        if needsGrid { Task { await loadGrid() } }
    }

    /// Re-reads the queue, after this model or anyone else changed it.
    func queueDidChange() {
        let queued = queuedPrices()
        for index in rows.indices where rows[index].queued != queued[rows[index].id] {
            rows[index].queued = queued[rows[index].id]
        }
    }

    func stopFollowing() {
        isFollowing = false
        refollowTask?.cancel()
    }

    /// The schedule sheet's Save: every queued change of this product (and
    /// every later one) takes effect on the new schedule.
    func setSchedule(_ schedule: PriceSchedule) {
        self.schedule = schedule
        schedule.apply(in: queue, appID: appID, productID: product.id)
        rebuild(recommendations: false)
    }

    // MARK: - Writing

    /// Writes new prices to the queue in one save; a price equal to today's
    /// drops the territory's pending change instead.
    func write(_ points: [String: PricePoint], source: ChangeSource) {
        let factory = PriceChangeFactory(appID: appID, product: product, schedule: schedule)
        var upserts: [PendingChange] = []
        var discards: [PendingChange.ID] = []
        for (territoryID, point) in points {
            guard let row = row(id: territoryID) else { continue }
            if PricingRow.differs(point.customerPrice, row.current.customerPrice) {
                upserts.append(factory.change(for: row.territory, from: row.current, to: point, source: source))
            } else if row.queued != nil {
                discards.append(PriceChangeFactory.changeID(productID: product.id, territoryID: territoryID))
            }
        }
        queue.discard(ids: discards)
        queue.upsert(contentsOf: upserts.sorted { $0.title < $1.title })
        queueDidChange()
    }

    /// Makes sure Apple's ladders are here for these territories, since only
    /// their points can be pushed. Returns false if they couldn't load.
    func ensureLadders(for territoryIDs: [String]) async -> Bool {
        let missing = sheet.missingLadders(in: territoryIDs)
        guard !missing.isEmpty else { return true }
        let everyMissing = Set(sheet.missingLadders(in: sheet.prices.keys))
        isLoadingLadders = true
        defer { isLoadingLadders = false }
        do {
            let ladders = try await services.ladders(for: product, territoryIDs: missing, commission: calculator.commission)
            sheet.merge(ladders)
            // A read of every territory left is the whole grid.
            if Set(missing).isSuperset(of: everyMissing) { grid = .ready }
            rebuild(recommendations: true)
            return true
        } catch {
            onError(error)
            return false
        }
    }

    /// Reads Apple's price points for every territory still on a simulated
    /// ladder, once: a caller while it runs waits for the same read, and the
    /// services read each product once at a time. Suggestions are built
    /// when they arrive; a failure keeps today's prices, suggests nothing
    /// and says why (`grid`). The read runs to its end even when the view
    /// that asked goes away, so its points are kept.
    func loadGrid() async {
        if let gridTask {
            await gridTask.value
            return
        }
        let missing = sheet.missingLadders(in: sheet.prices.keys)
        guard !missing.isEmpty else {
            grid = .ready
            return
        }
        grid = .checking
        let task = Task { [weak self] in
            guard let self else { return }
            await readGrid(missing)
        }
        gridTask = task
        await task.value
        gridTask = nil
    }

    /// Follows the strategy everywhere: every territory without a hand edit
    /// gets the strategy's price as a pending change.
    func follow() async {
        isFollowing = true
        guard await ensureLadders(for: rows.map(\.id)) else { return }
        writeTargets()
    }

    // MARK: - Private

    private func readGrid(_ territoryIDs: [String]) async {
        do {
            let ladders = try await services.ladders(for: product, territoryIDs: territoryIDs, commission: calculator.commission)
            sheet.merge(ladders)
            // Done: a territory Apple sent no points for suggests nothing.
            grid = .ready
        } catch {
            grid = .failed(AppleErrorCopy(PriceGridState.failureTitle, error: error))
        }
        rebuild(recommendations: true)
    }

    private var builder: PricingRowBuilder {
        var builder = PricingRowBuilder(
            catalog: territories,
            calculator: calculator,
            sheet: sheet,
            strategy: strategy,
            showsSuggestions: showsSuggestions,
            isScheduled: schedule.isScheduled
        )
        builder.isGridReady = grid.isReady
        return builder
    }

    /// The base price waiting in Review & Push the suggestions were last
    /// worked out from (`PricingRowBuilder.queuedBasePrice`).
    @ObservationIgnored private var suggestedFromBase: Decimal?

    private func rebuild(recommendations recompute: Bool) {
        let queued = queuedPrices()
        var builder = builder
        builder.queuedBasePrice = queued[sheet.baseTerritoryID]?.price
        if recompute || builder.queuedBasePrice != suggestedFromBase {
            recommendations = builder.recommendations()
            suggestedFromBase = builder.queuedBasePrice
        }
        rows = builder.rows(recommendations: recommendations, queued: queued).map { row in
            var row = row
            row.isInPriceTest = priceTestTerritories.contains(row.id)
            return row
        }
    }

    private func queuedPrices() -> [String: QueuedPrice] {
        let prefix = PriceChangeFactory.changeID(productID: product.id, territoryID: "")
        var result: [String: QueuedPrice] = [:]
        for change in queue.changes(for: appID, section: .subscriptionPricing) where change.id.hasPrefix(prefix) {
            let territoryID = String(change.id.dropFirst(prefix.count))
            guard let territory = territories.territory(alpha3: territoryID) else { continue }
            result[territoryID] = QueuedPrice(change: change, territory: territory)
        }
        return result
    }

    /// The strategy's price for every row without a hand edit.
    func writeTargets() {
        var points: [String: PricePoint] = [:]
        for row in rows where !(row.queued?.isManual ?? false) && !row.isBase {
            points[row.id] = row.target
        }
        write(points, source: .suggestion)
    }

    /// While following, a strategy edit rewrites the proposals once the
    /// person pauses, so dragging a slider doesn't rewrite the queue each step.
    private func scheduleRefollow() {
        refollowTask?.cancel()
        refollowTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.writeTargets()
        }
    }
}
