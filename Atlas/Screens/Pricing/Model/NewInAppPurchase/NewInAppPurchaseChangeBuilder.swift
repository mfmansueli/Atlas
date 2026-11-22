//
//  NewInAppPurchaseChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns a new in-app purchase into one Review & Push change, shown as
/// "Create Atlas Pro Lifetime" with its fields. Its requests, in order:
///
/// 1. `POST /v2/inAppPurchases` for the app (`NewInAppPurchaseCreate`
///    finds the one a push before created).
/// 2. Its display name and description in `POST /v2/inAppPurchaseLocalizations`
///    into its texts' version (`InAppDraftWrite`), like a subscription's.
/// 3. Availability in every country or region App Store Connect has, and
///    in new ones (`InAppPurchaseAvailabilityEverywhere`).
/// 4. Its price schedule: the US price point at the price as the base
///    territory's manual price; Apple equalizes the rest
///    (`InAppPurchaseStartingPrice`).
/// 5. Its App Review screenshot, when one was given.
///
/// A failure resumes after the steps that went through.
struct NewInAppPurchaseChangeBuilder {
    let app: StoreApp
    var folder: PurchaseReviewScreenshotFolder = .shared

    static let idPrefix = "inAppPurchaseSetup."
    static let type = "inAppPurchases"

    /// `inAppPurchaseSetup.<appID>.<productID>`: proposing the same product
    /// ID again replaces the change.
    static func changeID(appID: StoreApp.ID, productID: String) -> PendingChange.ID {
        "\(idPrefix)\(appID).\(productID)"
    }

    static func owns(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    /// The app's new in-app purchases waiting in Review & Push.
    @MainActor
    static func queued(in queue: ChangeQueue, appID: StoreApp.ID) -> [PendingChange] {
        queue.changes(for: appID, section: .subscriptionPricing).filter { owns($0) && $0.creation != nil }
    }

    /// A queued new in-app purchase's product ID.
    static func productID(of change: PendingChange) -> String? {
        change.creation?.fields.first { $0.id == "productId" }?.newValue
    }

    var group: String { String(localized: "Subscription Pricing · New in-app purchases") }

    func change(
        for purchase: NewInAppPurchase,
        problems: [NewSubscriptionProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let id = Self.changeID(appID: app.id, productID: NewSubscription.trimmed(purchase.productID))
        var change = PendingChange(
            id: id,
            appID: app.id,
            section: .subscriptionPricing,
            group: group,
            title: NewSubscription.trimmed(purchase.referenceName),
            oldValue: "",
            newValue: [purchase.kind.title, purchase.formattedPrice].compactMap(\.self).joined(separator: " · "),
            source: source,
            blockedReason: problems.first?.message,
            requests: requests(for: purchase),
            createdAt: date
        )
        change.creation = PendingCreation(
            id: id,
            title: String(localized: "Create \(change.title)"),
            detail: String(localized: """
            A \(purchase.kind.title.lowercased()) in-app purchase for \(app.name), available in every country or region. \
            Submit it for App Review with the app’s next version.
            """),
            source: source,
            fields: fields(of: purchase, source: source, evidence: evidence)
        )
        return change
    }

    // MARK: - Requests

    func requests(for purchase: NewInAppPurchase) -> [PushRequest] {
        let purchaseID = PushRequest.createdIDPlaceholder(type: Self.type)
        var requests = [create(purchase)]
        var texts: [String: String?] = ["locale": purchase.locale.code, "name": NewSubscription.trimmed(purchase.displayName)]
        let description = NewSubscription.trimmed(purchase.description)
        if !description.isEmpty { texts["description"] = description }
        let document = StorePageWriteDocument.create(
            type: "inAppPurchaseLocalizations",
            attributes: texts,
            parent: "version",
            parentType: "inAppPurchaseVersions",
            parentID: PushRequest.inAppDraftPlaceholder(ownerType: Self.type, ownerID: purchaseID)
        )
        requests.append(PushRequest(method: .post, path: "/v2/inAppPurchaseLocalizations", body: document.encoded()))
        requests.append(InAppPurchaseAvailabilityEverywhere.request(purchaseID: purchaseID))
        if let price = purchase.price {
            requests.append(InAppPurchaseStartingPrice(purchaseID: purchaseID, territoryID: NewSubscription.baseTerritoryID, customerPrice: price).request)
        }
        if let file = purchase.reviewScreenshot {
            let step = PurchaseReviewScreenshotChangeBuilder(app: app, folder: folder).step(file, owner: .inAppPurchase, ownerID: purchaseID)
            requests.append(step.request)
        }
        return requests
    }

    private func create(_ purchase: NewInAppPurchase) -> PushRequest {
        var attributes: [String: Any] = [
            "name": NewSubscription.trimmed(purchase.referenceName),
            "productId": NewSubscription.trimmed(purchase.productID),
            "inAppPurchaseType": purchase.kind.rawValue,
            "familySharable": purchase.sentFamilySharable,
        ]
        let note = NewSubscription.trimmed(purchase.reviewNote)
        if !note.isEmpty { attributes["reviewNote"] = note }
        return PushPagedRead.request(.post, NewInAppPurchaseCreate.path, [
            "data": [
                "type": Self.type,
                "attributes": attributes,
                "relationships": ["app": ["data": ["type": "apps", "id": app.id]]],
            ],
        ])
    }

    // MARK: - Review & Push

    private func fields(of purchase: NewInAppPurchase, source: ChangeSource, evidence: [String]) -> [PendingChangePart] {
        let language = purchase.locale.name
        var fields: [(String, String, String)] = [
            ("productId", NewSubscriptionField.productID.title, NewSubscription.trimmed(purchase.productID)),
            ("type", String(localized: "Type"), purchase.kind.title),
            ("name", String(localized: "Display name · \(language)"), NewSubscription.trimmed(purchase.displayName)),
            ("description", String(localized: "Description · \(language)"), NewSubscription.trimmed(purchase.description)),
            ("price", NewSubscriptionField.price.title, purchase.formattedPrice.map {
                String(localized: "\($0) in the United States · equalized everywhere else")
            } ?? ""),
        ]
        if purchase.kind.supportsFamilySharing {
            let sharing = purchase.isFamilySharable ? String(localized: "On") : String(localized: "Off")
            fields.append(("familySharing", String(localized: "Family Sharing"), sharing))
        }
        let note = NewSubscription.trimmed(purchase.reviewNote)
        if !note.isEmpty { fields.append(("reviewNote", NewSubscriptionField.reviewNote.title, note)) }
        if let file = purchase.reviewScreenshot {
            fields.append((PurchaseReviewScreenshotChangeBuilder.fieldID, String(localized: "Review screenshot"), file.summary))
        }
        if !evidence.isEmpty { fields.append(("evidence", String(localized: "Found in"), evidence.joined(separator: "\n"))) }
        return fields.map { PendingChangePart(id: $0.0, title: $0.1, oldValue: "", newValue: $0.2, source: source) }
    }
}
