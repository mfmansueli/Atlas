//
//  PendingChange+QueuedSubscription.swift
//  Atlas
//

import Foundation

// Changes that wait for a new subscription (`QueuedSubscriptionPlaceholder`).
extension PendingChange {
    /// Whether an edit of this change keeps the changes that depend on it.
    /// A new subscription's offers still go into it when it's proposed
    /// again or gets an introductory offer: its product ID, and so its
    /// change, stay. A new version's texts go with an old version number
    /// (`ChangeQueue.upsert`).
    var keepsDependentsWhenEdited: Bool {
        NewSubscriptionChangeBuilder.owns(self)
    }

    /// The change with the subscription App Store Connect created in place
    /// of `placeholder`: its requests and `groupID` name the ID, and it
    /// depends on nothing now, as if it had been proposed for a
    /// subscription App Store Connect has.
    func resolvingQueuedSubscription(_ placeholder: QueuedSubscriptionPlaceholder, id: String) -> PendingChange {
        var change = self
        change.requests = requests.map { $0.replacing(placeholder.token, with: id) }
        change.restoreRequests = restoreRequests.map { $0.replacing(placeholder.token, with: id) }
        change.alternative?.requests = alternative?.requests.map { $0.replacing(placeholder.token, with: id) } ?? []
        change.alternative?.restoreRequests = alternative?.restoreRequests.map { $0.replacing(placeholder.token, with: id) } ?? []
        if change.groupID == placeholder.token { change.groupID = id }
        change.dependsOn = nil
        return change
    }
}
