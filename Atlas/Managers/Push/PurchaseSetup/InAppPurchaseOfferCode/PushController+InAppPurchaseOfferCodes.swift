//
//  PushController+InAppPurchaseOfferCodes.swift
//  Atlas
//

import Foundation

// An in-app purchase's offer code with its prices, a custom code and a
// batch of one-time codes for one: each is one queued request the push
// turns into the reads and the write it needs, and each finds what a push
// of it made before instead of making it twice.
extension PushController {
    /// Sends `request` when it's one of these steps; false for any other.
    func sendInAppPurchaseOfferCodeStep(_ request: PushRequest, at index: Int, transport: any PushTransport) async throws -> Bool {
        if let write = InAppPurchaseOfferCodeWrite(request) {
            let id = try await write.send(via: transport) { noteRequest($0) }
            update(index) { item in
                item.createdID = id
                item.createdIDs[InAppPurchaseOfferCodeResource.offerCodeType] = id
            }
            return true
        }
        if let create = InAppPurchaseCustomCodeCreate(request) {
            let id = try await create.send(via: transport) { noteRequest($0) }
            update(index) { $0.createdIDs[InAppPurchaseOfferCodeResource.customCodeType] = id }
            return true
        }
        guard let create = InAppPurchaseOneTimeCodesCreate(request) else { return false }
        // A change makes one batch: the one this push made already stands.
        guard items[index].createdIDs[InAppPurchaseOfferCodeResource.oneTimeCodesType] == nil else { return true }
        let id = try await create.send(via: transport) { noteRequest($0) }
        update(index) { $0.createdIDs[InAppPurchaseOfferCodeResource.oneTimeCodesType] = id }
        return true
    }
}
