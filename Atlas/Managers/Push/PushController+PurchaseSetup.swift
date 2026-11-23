//
//  PushController+PurchaseSetup.swift
//  Atlas
//

import Foundation

// A new in-app purchase's steps, a new subscription's or in-app purchase's
// availability everywhere, a subscription's introductory offer, a
// promotional offer, win-back offer or offer code with its prices, and a
// product's App Review screenshot: each is one queued request the push
// turns into the reads and writes it needs.
extension PushController {
    /// Sends `request` when it's one of these steps; false for any other.
    func sendPurchaseSetupStep(_ request: PushRequest, at index: Int, transport: any PushTransport) async throws -> Bool {
        if let availability = SubscriptionAvailabilityEverywhere(request) {
            let territories = try await everyTerritory(transport: transport)
            let response = try await transport.send(availability.request(territoryIDs: territories))
            noteRequest(response.rateLimit)
            return true
        }
        if let create = NewInAppPurchaseCreate(request) {
            let id = try await create.send(via: transport) { noteRequest($0) }
            update(index) { item in
                item.createdID = id
                item.createdIDs[NewInAppPurchaseChangeBuilder.type] = id
            }
            return true
        }
        if let availability = InAppPurchaseAvailabilityEverywhere(request) {
            let territories = try await everyTerritory(transport: transport)
            let response = try await transport.send(availability.request(territoryIDs: territories))
            noteRequest(response.rateLimit)
            return true
        }
        if let price = InAppPurchaseStartingPrice(request) {
            try await price.send(via: transport) { noteRequest($0) }
            return true
        }
        if let offer = IntroductoryOfferEverywhere(request) {
            defer { update(index) { $0.progressNote = nil } }
            try await offer.send(via: transport) { made, total in
                update(index) { $0.progressNote = String(localized: "Introductory offer · \(made) of \(total)") }
            } note: { rateLimit in
                noteRequest(rateLimit)
            }
            return true
        }
        if let write = SubscriptionOfferWrite(request) {
            let id = try await write.send(via: transport) { noteRequest($0) }
            update(index) { item in
                item.createdID = id
                item.createdIDs[write.resource.type] = id
            }
            return true
        }
        guard let screenshot = PurchaseReviewScreenshotPush(request) else { return false }
        defer { update(index) { $0.progressNote = nil } }
        try await screenshot.send(
            via: transport,
            note: { noteRequest($0) },
            progress: { note in update(index) { $0.progressNote = note } }
        )
        return true
    }
}
