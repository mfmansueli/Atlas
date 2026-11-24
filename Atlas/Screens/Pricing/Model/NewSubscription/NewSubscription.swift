//
//  NewSubscription.swift
//  Atlas
//

import Foundation

/// A subscription to create in App Store Connect, as Create Subscription
/// or an assistant's `propose_subscription` fills it in. The push creates
/// it (and its group when that's new), writes its texts, makes it available
/// everywhere and sets its starting price (`NewSubscriptionChangeBuilder`).
struct NewSubscription: Hashable, Sendable {
    var group: NewSubscriptionGroup
    /// App Store Connect's internal name, e.g. "Bruma Premium Monthly".
    var referenceName: String
    /// The ID the app's code buys, e.g. `com.lima.bruma.premium.monthly`.
    /// It can't be changed or used again once it's created.
    var productID: String
    var period: SubscriptionPeriod
    var isFamilySharable = false
    /// The language its display name and description are written in: the
    /// app's primary one.
    var locale: StoreLocale
    /// What customers see on the purchase sheet and in Settings.
    var displayName: String
    var description: String
    /// The price in the United States, in US dollars; every other country
    /// or region gets Apple's equalized price, or the recommended one
    /// (`priceChoice`).
    var price: Decimal?
    /// What it costs in the other countries and regions.
    var priceChoice: NewSubscriptionPriceChoice = .equalized
    /// With `.recommended`, the local prices that differ from Apple's
    /// equalized ones, by alpha-3 (`NewSubscriptionRecommendation.prices`).
    var recommendedPrices: [String: Decimal] = [:]
    /// For App Review, e.g. how to reach the paywall.
    var reviewNote = ""
    /// What App Review sees: the paywall. Without one the subscription
    /// stays in Missing Metadata and StoreKit doesn't return it.
    var reviewScreenshot: PurchaseReviewScreenshotFile?

    /// Where the starting price is set; the others are equalized with it.
    static let baseTerritoryID = "USA"

    /// The prices the push sets apart from Apple's equalized ones.
    var priceOverrides: [String: Decimal] {
        priceChoice == .recommended ? recommendedPrices : [:]
    }

    /// The price as the App Store writes it in the United States: "$9.99".
    var formattedPrice: String? {
        price.map { CurrencyFormat.forCurrency("USD").format($0) }
    }

    /// The parts of a product ID suggested for each period: `monthly`.
    static func productIDSuffix(for period: SubscriptionPeriod) -> String {
        switch period {
        case .oneWeek: "weekly"
        case .oneMonth: "monthly"
        case .twoMonths: "bimonthly"
        case .threeMonths: "quarterly"
        case .sixMonths: "semiannual"
        case .oneYear: "annual"
        }
    }

    /// "Bruma" for "Bruma – Gay Dating Nearby": the name before a dash or
    /// a colon, for the suggested group and reference names.
    static func shortName(of appName: String) -> String {
        let separators = [" – ", " — ", " - ", ": "]
        let short = separators.reduce(appName) { name, separator in
            name.components(separatedBy: separator).first ?? name
        }
        return short.trimmingCharacters(in: .whitespaces)
    }
}
