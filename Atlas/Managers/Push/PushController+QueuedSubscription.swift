//
//  PushController+QueuedSubscription.swift
//  Atlas
//

import Foundation

// A new subscription's offers (`QueuedSubscriptionPlaceholder`): they're
// pushed after it (`QueuedVersionPushOrder`, `PushSchedule`: a change that
// depends on another waits for it), get its ID once App Store Connect made
// it, and wait in the queue until then.
extension PushController {
    /// Takes the change at `index`, which went through, off the queue. When
    /// it created a new subscription, the changes waiting for it name its ID
    /// from now on, in this push (each is read from the queue when it
    /// starts) and later ones.
    func removePushed(_ index: Int) {
        let change = items[index].change
        queue.remove(pushed: change.id)
        guard NewSubscriptionChangeBuilder.owns(change), let productID = NewSubscriptionChangeBuilder.productID(of: change),
              let id = items[index].createdIDs["subscriptions"]
        else { return }
        let placeholder = QueuedSubscriptionPlaceholder(productID: productID)
        let waiting = queue.changes.filter { $0.appID == change.appID && $0.dependsOn == change.id }
        queue.upsert(contentsOf: waiting.map { $0.resolvingQueuedSubscription(placeholder, id: id) })
    }

    /// `request`, or throws when it still names a new subscription: it
    /// wasn't created, so the request waits.
    func checkingQueuedSubscription(in request: PushRequest) throws -> PushRequest {
        guard let placeholder = QueuedSubscriptionPlaceholder.first(in: request) else { return request }
        throw QueuedSubscriptionPlaceholder.NotCreated(productID: placeholder.productID)
    }
}
