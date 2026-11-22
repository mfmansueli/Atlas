//
//  PurchaseReviewScreenshotChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns an App Review screenshot into Review & Push: for a product App
/// Store Connect has, its own change, "Review screenshot" with the file,
/// which replaces the one it had; for a new subscription or in-app purchase
/// waiting in Review & Push, one more step of its change, into
/// `{createdID:<type>}`. The push uploads it (`PurchaseReviewScreenshotPush`).
struct PurchaseReviewScreenshotChangeBuilder {
    let app: StoreApp
    var folder: PurchaseReviewScreenshotFolder = .shared

    static let idPrefix = "reviewScreenshot."
    /// The field a new product's change lists the screenshot under.
    static let fieldID = "reviewScreenshot"

    /// `reviewScreenshot.<appID>.<productID>`: another screenshot for the
    /// same product replaces the change.
    static func changeID(appID: StoreApp.ID, productID: String) -> PendingChange.ID {
        "\(idPrefix)\(appID).\(productID)"
    }

    static func owns(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    /// The upload a change sends: its own, or a new product's.
    static func screenshot(in change: PendingChange) -> PurchaseReviewScreenshotPush? {
        change.requests.lazy.compactMap(PurchaseReviewScreenshotPush.init).first
    }

    /// The upload step for `file` into `ownerID`.
    func step(_ file: PurchaseReviewScreenshotFile, owner: PurchaseReviewScreenshotOwner, ownerID: String) -> PurchaseReviewScreenshotPush {
        PurchaseReviewScreenshotPush(
            owner: owner, ownerID: ownerID, fileName: file.fileName, fileSize: file.byteCount,
            path: folder.path(for: file, appID: app.id), checksum: file.checksum
        )
    }

    /// A screenshot for `product`, which App Store Connect has.
    func change(
        for file: PurchaseReviewScreenshotFile,
        product: PricingProduct,
        current: PurchaseReviewScreenshotState? = nil,
        source: ChangeSource = .you,
        at date: Date = .now
    ) -> PendingChange {
        let owner: PurchaseReviewScreenshotOwner = product.isInAppPurchase ? .inAppPurchase : .subscription
        return PendingChange(
            id: Self.changeID(appID: app.id, productID: product.productID),
            appID: app.id,
            section: .subscriptionPricing,
            group: String(localized: "Subscription Pricing · \(product.name)"),
            title: String(localized: "Review screenshot"),
            oldValue: current.flatMap(\.fileName) ?? String(localized: "None"),
            newValue: file.summary,
            source: source,
            requests: [step(file, owner: owner, ownerID: product.id).request],
            createdAt: date
        )
    }

    /// A new product's change with `file` as its last step, in place of the
    /// one it had.
    func attaching(
        _ file: PurchaseReviewScreenshotFile,
        owner: PurchaseReviewScreenshotOwner,
        to change: PendingChange,
        source: ChangeSource
    ) -> PendingChange {
        var change = Self.detaching(from: change)
        change.requests.append(step(file, owner: owner, ownerID: PushRequest.createdIDPlaceholder(type: owner.ownerType)).request)
        change.creation?.fields.append(PendingChangePart(
            id: Self.fieldID,
            title: String(localized: "Review screenshot"),
            oldValue: "",
            newValue: file.summary,
            source: source
        ))
        return change
    }

    /// The change without its screenshot step and field.
    static func detaching(from change: PendingChange) -> PendingChange {
        var change = change
        change.requests.removeAll { PurchaseReviewScreenshotPush($0) != nil }
        change.creation?.fields.removeAll { $0.id == fieldID }
        return change
    }
}
