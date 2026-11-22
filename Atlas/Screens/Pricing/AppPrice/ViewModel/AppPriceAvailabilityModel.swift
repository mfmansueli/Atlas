//
//  AppPriceAvailabilityModel.swift
//  Atlas
//

import Foundation
import Observation

/// Pricing's App Price and Availability cards for one app, as App Store
/// Connect's Pricing and Availability page has them: the app's price (or
/// Add Pricing… when it has none) and where it's sold (or Set Up
/// Availability…). Every edit is a change in Review & Push.
@MainActor
@Observable
final class AppPriceAvailabilityModel {
    let app: StoreApp
    private(set) var price: LoadState<AppPriceState> = .idle
    private(set) var availability: LoadState<AppAvailabilityState> = .idle
    /// Every country or region App Store Connect has, for the setup sheet.
    private(set) var territories: LoadState<[AppTerritory]> = .idle
    /// Apple's price points by territory, read when the price sheet asks.
    private(set) var ladders: [String: LoadState<PricePointLadder>] = [:]

    var isPriceSheetPresented = false
    var isAvailabilitySheetPresented = false

    /// Today, for pre-order dates; DEBUG scenes and tests pin it.
    var today: () -> Date = { .now }
    /// Opens Review & Push.
    var onOpenReview: () -> Void = {}

    @ObservationIgnored let services: any AppPriceAvailabilityServices
    @ObservationIgnored let queue: ChangeQueue

    init(app: StoreApp, services: any AppPriceAvailabilityServices, queue: ChangeQueue) {
        self.app = app
        self.services = services
        self.queue = queue
    }

    // MARK: - Reading

    /// The price and the availability; what's shown stays while they're
    /// read again.
    func load() async {
        await loadPrice()
        await loadAvailability()
    }

    func loadPrice() async {
        if price.value == nil { price = .loading }
        do {
            price = try await .loaded(services.appPrice(for: app))
        } catch {
            price = .failed(error.localizedDescription)
        }
    }

    func loadAvailability() async {
        if availability.value == nil { availability = .loading }
        do {
            availability = try await .loaded(services.availability(for: app))
        } catch {
            availability = .failed(error.localizedDescription)
        }
    }

    /// Apple's territories, once.
    func loadTerritories() async {
        guard territories.value == nil, !territories.isLoading else { return }
        territories = .loading
        do {
            territories = try await .loaded(services.territories())
        } catch {
            territories = .failed(error.localizedDescription)
        }
    }

    func ladder(for territoryID: String) -> LoadState<PricePointLadder> {
        ladders[territoryID] ?? .idle
    }

    /// A territory's price points, once (again after a failure).
    func loadLadder(for territoryID: String) async {
        switch ladder(for: territoryID) {
        case .loaded, .loading: return
        case .idle, .failed: break
        }
        ladders[territoryID] = .loading
        do {
            ladders[territoryID] = try await .loaded(services.pricePoints(for: app, territoryID: territoryID))
        } catch {
            ladders[territoryID] = .failed(error.localizedDescription)
        }
    }

    // MARK: - What's queued

    var queuedPrice: PendingChange? {
        AppPriceChangeBuilder.queued(in: queue, appID: app.id)
    }

    var queuedSetup: PendingChange? {
        AppAvailabilityChangeBuilder.queuedSetup(in: queue, appID: app.id)
    }

    /// The setup the queued change sends, for the card's counts.
    var queuedSetupValue: AppAvailabilitySetup? {
        queuedSetup?.requests.first.flatMap(AppPriceAvailabilityRequests.availabilitySetup(in:))
    }

    /// Whether the app is sold in a territory once the queue is pushed.
    func isAvailable(_ territory: AppTerritoryAvailability) -> Bool {
        AppAvailabilityChangeBuilder.queuedTerritoryWrites(in: queue, appID: app.id)[territory.id] ?? territory.isAvailable
    }

    /// Countries and regions turned on or off in Review & Push.
    var queuedTerritoryCount: Int {
        guard let availability = availability.value?.availability else { return 0 }
        let writes = AppAvailabilityChangeBuilder.queuedTerritoryWrites(in: queue, appID: app.id)
        return availability.territories.count { territory in writes[territory.id].map { $0 != territory.isAvailable } ?? false }
    }

    /// Where the app is sold once the queue is pushed.
    var shownAvailableCount: Int {
        guard let availability = availability.value?.availability else { return 0 }
        return availability.territories.count(where: isAvailable)
    }

    /// The base territory the price sheet starts in: today's, else the
    /// United States.
    var defaultBaseTerritory: AppTerritory {
        if let current = price.value?.current { return AppTerritory(id: current.baseTerritoryID, currencyCode: current.currencyCode) }
        return .unitedStates
    }

    // MARK: - Changes

    /// The price sheet's Add to Review & Push.
    func queuePrice(_ point: PricePoint, in territory: AppTerritory) {
        let change = AppPriceChangeBuilder(app: app).change(point: point, in: territory, replacing: price.value ?? .notSet)
        queue.upsert(change)
        isPriceSheetPresented = false
    }

    func discardQueuedPrice() {
        queue.discard(id: AppPriceChangeBuilder.changeID(appID: app.id))
    }

    /// Problems Set Up Availability… shows before it queues anything.
    func problems(for setup: AppAvailabilitySetup) -> [AppAvailabilityProblem] {
        AppAvailabilityRules.problems(for: setup, today: today())
    }

    /// Set Up Availability…'s Add to Review & Push.
    func queueSetup(_ setup: AppAvailabilitySetup) {
        let change = AppAvailabilityChangeBuilder(app: app).setupChange(setup, problems: problems(for: setup))
        queue.upsert(change)
        isAvailabilitySheetPresented = false
    }

    func discardQueuedSetup() {
        queue.discard(id: AppAvailabilityChangeBuilder.setupChangeID(appID: app.id))
    }

    /// The availability sheet's Add to Review & Push: a change for every
    /// country or region that differs from App Store Connect, and none
    /// (the queued one discarded) for one put back as it is.
    func queueTerritories(_ wanted: [String: Bool]) {
        guard let availability = availability.value?.availability else { return }
        let builder = AppAvailabilityChangeBuilder(app: app)
        var changes: [PendingChange] = []
        var unchanged: [PendingChange.ID] = []
        for territory in availability.territories {
            guard let isOn = wanted[territory.territoryID] else { continue }
            if let change = builder.territoryChange(territory, available: isOn) {
                changes.append(change)
            } else {
                unchanged.append(AppAvailabilityChangeBuilder.territoryChangeID(appID: app.id, territoryID: territory.territoryID))
            }
        }
        queue.discard(ids: unchanged.filter { queue.change(id: $0) != nil })
        if !changes.isEmpty { queue.upsert(contentsOf: changes) }
        isAvailabilitySheetPresented = false
    }
}
