//
//  InAppReviewNoteChangeBuilder.swift
//  Atlas
//

import Foundation

/// A subscription's or in-app purchase's Review Notes (Review Information ›
/// Review Notes in App Store Connect) as a Review & Push change: one
/// `PATCH` of `reviewNote` on the product (`/v2/inAppPurchases/{id}` or
/// `/v1/subscriptions/{id}`), restorable, with a conflict check. The notes
/// are for App Review only and one per product, so they aren't localized
/// and don't follow the store text rules.
///
/// Ids are `storePage.<appID>.inAppReviewNote.<productID>`: outside
/// `InAppTextChangeBuilder`'s `storePage.<appID>.inApp.` prefix, so In-App
/// Texts' resync leaves them alone.
struct InAppReviewNoteChangeBuilder: Hashable, Sendable {
    let appID: StoreApp.ID
    let content: InAppTextsContent

    /// App Store Connect's limit (In-App Purchase information reference).
    static let limit = 4000

    /// States App Store Connect doesn't take edits in: the product is with
    /// App Review, alone or with the app's next version.
    static let lockedStates: Set = ["WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_BINARY_APPROVAL"]

    /// States whose edits apply when the product is next sent for review.
    static let nextSubmissionStates: Set = ["APPROVED", "DEVELOPER_REMOVED_FROM_SALE", "REMOVED_FROM_SALE"]

    var idPrefix: String { "storePage.\(appID).inAppReviewNote." }

    func changeID(_ productID: String) -> PendingChange.ID { idPrefix + productID }

    func owns(_ change: PendingChange) -> Bool {
        change.section == .storePage && change.appID == appID && change.id.hasPrefix(idPrefix)
    }

    /// The product a queued change is for.
    func productID(of change: PendingChange) -> String? {
        owns(change) ? String(change.id.dropFirst(idPrefix.count)) : nil
    }

    /// "Review Notes · Complete".
    static func group(_ product: InAppTextProduct) -> String {
        String(localized: "Review Notes · \(product.referenceName)")
    }

    /// The change that sets `product`'s notes to `note`, or nil when App
    /// Store Connect has no resource for it yet. `reason` shows under the
    /// heading in Review & Push.
    func change(_ product: InAppTextProduct, to note: String, source: ChangeSource, reason: String? = nil) -> PendingChange? {
        guard let resourceID = content.productResourceIDs[product.id] else { return nil }
        let old = content.reviewNotes[product.id] ?? ""
        let path = Self.path(product.kind, id: resourceID)
        return PendingChange(
            id: changeID(product.id),
            appID: appID,
            section: .storePage,
            group: Self.group(product),
            groupNote: reason.flatMap { $0.isEmpty ? nil : $0 },
            title: String(localized: "Review Notes · \(product.id)"),
            oldValue: old,
            newValue: note,
            source: source,
            requests: [Self.patch(product.kind, id: resourceID, note: note)],
            restoreRequests: [Self.patch(product.kind, id: resourceID, note: old.isEmpty ? nil : old)],
            conflictCheck: ConflictCheck(path: path, keyPath: ["data", "attributes", "reviewNote"], expected: old.isEmpty ? nil : old)
        )
    }

    /// `/v2/inAppPurchases/{id}` or `/v1/subscriptions/{id}`.
    static func path(_ kind: InAppTextProductKind, id: String) -> String {
        switch kind {
        case .inAppPurchase: "/v2/inAppPurchases/\(id)"
        case .subscription: "/v1/subscriptions/\(id)"
        }
    }

    static func patch(_ kind: InAppTextProductKind, id: String, note: String?) -> PushRequest {
        let type = kind == .inAppPurchase ? "inAppPurchases" : "subscriptions"
        let document: [String: Any] = [
            "data": ["type": type, "id": id, "attributes": ["reviewNote": note.map { $0 as Any } ?? NSNull()]],
        ]
        let body = (try? JSONSerialization.data(withJSONObject: document, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return PushRequest(method: .patch, path: path(kind, id: id), body: body)
    }
}
