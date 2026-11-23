//
//  QueuedSubscriptionPlaceholder.swift
//  Atlas
//

import Foundation

/// A new subscription waiting in Review & Push, named in another change's
/// requests before App Store Connect gives it an ID:
/// `{queuedSubscription:<productID>}`. A promotional offer, win-back offer
/// or offer code proposed for it is its own change that depends on the
/// subscription's (`PendingChange.dependsOn`): it's pushed after it, and
/// discarded with it. Once the subscription is created, the push writes its
/// ID into them (`PendingChange.resolvingQueuedSubscription`); until then,
/// they wait in the queue (`NotCreated`).
struct QueuedSubscriptionPlaceholder: Hashable, Sendable {
    var productID: String

    static let opening = "{queuedSubscription:"

    var token: String {
        "\(Self.opening)\(productID)}"
    }

    init(productID: String) {
        self.productID = productID
    }

    /// The placeholder `token` spells exactly; nil for anything else, an
    /// App Store Connect ID among them.
    init?(token: String) {
        guard token.hasPrefix(Self.opening), token.hasSuffix("}") else { return nil }
        let productID = String(token.dropFirst(Self.opening.count).dropLast())
        guard !productID.isEmpty, !productID.contains("}") else { return nil }
        self.productID = productID
    }

    /// The new subscription's change, in `appID`'s queue.
    func changeID(appID: StoreApp.ID) -> PendingChange.ID {
        NewSubscriptionChangeBuilder.changeID(appID: appID, productID: productID)
    }

    /// The first placeholder in `request`'s path or body, if it has one.
    static func first(in request: PushRequest) -> QueuedSubscriptionPlaceholder? {
        for text in [request.path, request.bodyText ?? ""] {
            guard let start = text.range(of: opening), let end = text[start.lowerBound...].firstIndex(of: "}") else { continue }
            if let placeholder = QueuedSubscriptionPlaceholder(token: String(text[start.lowerBound...end])) { return placeholder }
        }
        return nil
    }

    /// The subscription isn't in App Store Connect yet (it failed, wasn't
    /// pushed, or is blocked): what waits for it stays queued and goes out
    /// once it's created.
    struct NotCreated: LocalizedError, Equatable {
        var productID: String

        var errorDescription: String? {
            String(localized: "\(productID) isn’t in App Store Connect yet. Push the subscription first, then its offers.")
        }
    }
}
