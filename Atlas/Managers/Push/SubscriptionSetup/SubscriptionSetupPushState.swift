//
//  SubscriptionSetupPushState.swift
//  Atlas
//

import Foundation
import OSLog

/// What new subscriptions and starting prices share during one push: the
/// groups found or made (`SubscriptionGroupPlaceholder`), App Store
/// Connect's territories, and whether it refused batched prices. New
/// subscriptions go side by side (`PushSideBySideKey`), so each shared
/// step goes once, the others waiting for it (`PushSlots`).
@MainActor
final class SubscriptionSetupPushState {
    let slots: PushSlots
    /// Groups by `SubscriptionGroupPlaceholder.token`, so new subscriptions
    /// in the same new group share one.
    private var groups: [String: String] = [:]
    /// Every territory App Store Connect has, read once per push for new
    /// subscriptions' availability (`SubscriptionAvailabilityEverywhere`).
    private var territoryIDs: [String]?
    /// Set when App Store Connect refused a subscription's starting prices
    /// in batched `PATCH`es: the rest of the push sets them one territory
    /// at a time without asking again.
    private(set) var batchRefusal: AppStoreConnectError?

    private static let logger = Logger(subsystem: "com.lima.atlas", category: "Push")

    init(slots: PushSlots) {
        self.slots = slots
    }

    /// A new push.
    func reset() {
        groups = [:]
        territoryIDs = nil
        batchRefusal = nil
    }

    /// The group's ID, found or made once per push.
    func groupID(
        _ group: SubscriptionGroupPlaceholder,
        via transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String {
        try await slots.run("subscriptionGroup:\(group.token)") {
            if let known = groups[group.token] { return known }
            let found = try await group.send(via: transport)
            note(found.rateLimit)
            groups[group.token] = found.id
            return found.id
        }
    }

    /// Every territory App Store Connect has, read on first use in a push.
    func everyTerritory(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> [String] {
        try await slots.run("everyTerritory") {
            if let territoryIDs { return territoryIDs }
            let ids = try await SubscriptionAvailabilityEverywhere.territoryIDs(via: transport, note: note)
            territoryIDs = ids
            return ids
        }
    }

    /// Sets a subscription's starting prices: batched until App Store
    /// Connect refuses that once in the push, then one territory at a time.
    func send(
        _ prices: SubscriptionStartingPrices,
        via transport: any PushTransport,
        progress: (Int, Int) -> Void,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws {
        let refusal = try await prices.send(via: transport, slots: slots, batches: batchRefusal == nil, progress: progress, note: note)
        guard let refusal, batchRefusal == nil else { return }
        batchRefusal = refusal
        Self.logger.notice("Batched starting prices refused, sending them one territory at a time: \(String(describing: refusal), privacy: .public)")
    }
}
