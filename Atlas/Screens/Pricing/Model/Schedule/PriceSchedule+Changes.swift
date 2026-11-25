//
//  PriceSchedule+Changes.swift
//  Atlas
//

import Foundation

/// Reading a schedule back from queued price changes, and writing one into
/// them.
extension PriceSchedule {
    /// The schedule a queued price change was written with, or nil when its
    /// first request isn't a `POST /v1/subscriptionPrices` Atlas built.
    init?(change: PendingChange) {
        guard let request = change.requests.first.flatMap(Self.priceRequest) else { return nil }
        self.init(startDay: request.data.attributes.startDate, preservesCurrentPrice: request.data.attributes.preserveCurrentPrice)
    }

    /// The schedule of a subscription's queued price changes: the first one
    /// that has a readable request, else immediate.
    @MainActor
    static func current(in queue: ChangeQueue, appID: StoreApp.ID, productID: String) -> PriceSchedule {
        let prefix = PriceChangeFactory.changeID(productID: productID, territoryID: "")
        return queue.changes(for: appID, section: .subscriptionPricing)
            .lazy
            .filter { $0.id.hasPrefix(prefix) }
            .compactMap(PriceSchedule.init(change:))
            .first ?? .immediate
    }

    /// Writes this schedule into every queued price change of one
    /// subscription, as the schedule sheet's Save does; returns how many
    /// changes it rewrote.
    @MainActor
    @discardableResult
    func apply(in queue: ChangeQueue, appID: StoreApp.ID, productID: String) -> Int {
        let prefix = PriceChangeFactory.changeID(productID: productID, territoryID: "")
        let rewritten = queue.changes(for: appID, section: .subscriptionPricing)
            .filter { $0.id.hasPrefix(prefix) }
            .map(applied(to:))
        queue.upsert(contentsOf: rewritten)
        return rewritten.count
    }

    /// The change with this schedule: its price writes (and an assistant's
    /// alternative's) carry the start day and the subscriber choice, and the
    /// review group's note says so. Restore writes stay immediate.
    func applied(to change: PendingChange) -> PendingChange {
        var change = change
        change.requests = change.requests.map(applied)
        change.groupNote = note
        if var alternative = change.alternative {
            alternative.requests = alternative.requests.map(applied)
            change.alternative = alternative
        }
        return change
    }

    /// The request body for these attributes, as `PriceChangeFactory` builds it.
    func request(subscriptionID: String, territoryID: String, pricePointID: String) -> SubscriptionPriceCreateRequest {
        SubscriptionPriceCreateRequest(
            subscriptionID: subscriptionID,
            territoryID: territoryID,
            pricePointID: pricePointID,
            preserveCurrentPrice: preservesCurrentPrice,
            startDate: startDay
        )
    }

    // MARK: - Private

    private func applied(_ request: PushRequest) -> PushRequest {
        guard var body = Self.priceRequest(request) else { return request }
        body.data.attributes = SubscriptionPriceCreateRequest.Attributes(preserveCurrentPrice: preservesCurrentPrice, startDate: startDay)
        return (try? PushRequest.json(request.method, request.path, body)) ?? request
    }

    private static func priceRequest(_ request: PushRequest) -> SubscriptionPriceCreateRequest? {
        guard request.path == "/v1/subscriptionPrices", let body = request.body else { return nil }
        return try? JSONDecoder().decode(SubscriptionPriceCreateRequest.self, from: body)
    }
}
