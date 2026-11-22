//
//  NewInAppPurchase.swift
//  Atlas
//

import Foundation

/// An in-app purchase to create in App Store Connect, as Create In-App
/// Purchase or an assistant's `propose_in_app_purchase` fills it in. The
/// push creates it, writes its texts, makes it available everywhere, sets
/// its price in the United States (Apple equalizes the rest) and uploads its
/// App Review screenshot (`NewInAppPurchaseChangeBuilder`).
struct NewInAppPurchase: Hashable, Sendable {
    /// App Store Connect's internal name, e.g. "Atlas Pro Lifetime".
    var referenceName: String
    /// The ID the app's code buys, e.g. `pro.lifetime`. It can't be changed
    /// or used again once it's created.
    var productID: String
    var kind: NewInAppPurchaseKind = .nonConsumable
    var isFamilySharable = false
    /// The language its display name and description are written in: the
    /// app's primary one.
    var locale: StoreLocale
    /// What customers see on the purchase sheet.
    var displayName: String
    var description: String
    /// The price in the United States, in US dollars; every other country
    /// or region gets Apple's equalized price.
    var price: Decimal?
    /// For App Review, e.g. how to reach the paywall.
    var reviewNote = ""
    /// What App Review sees: the purchase in the app.
    var reviewScreenshot: PurchaseReviewScreenshotFile?

    /// "$149.99".
    var formattedPrice: String? {
        price.map { CurrencyFormat.forCurrency("USD").format($0) }
    }

    /// Family Sharing only where App Store Connect offers it.
    var sentFamilySharable: Bool {
        kind.supportsFamilySharing && isFamilySharable
    }
}
