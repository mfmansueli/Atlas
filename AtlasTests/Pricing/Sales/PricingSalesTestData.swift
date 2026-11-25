//
//  PricingSalesTestData.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Small App Analytics and Sales and Trends inputs for the Pricing sales
/// tests: a few facts on chosen days back from `through`.
enum PricingSalesTestData {
    static let through = AnalyticsDay(number: 20767)
    static let appID = "6450000001"

    static let annual = PricingProduct(id: "sub-annual", name: "Annual", productID: "lumen.annual", isInAppPurchase: false, reviewState: "Approved")
    static let monthly = PricingProduct(id: "sub-monthly", name: "Monthly", productID: "lumen.monthly", isInAppPurchase: false, reviewState: "Approved")
    static let lifetime = PricingProduct(id: "iap-life", name: "Lifetime", productID: "lumen.life", isInAppPurchase: true, reviewState: "Approved")

    static func views(_ count: Int, back: Int = 0, territory: String = "BR", downloads: Int = 0) -> EngagementFact {
        var fact = EngagementFact(day: through.adding(-back), territory: territory, source: "App Store Search", device: "iPhone")
        fact.pageViews = count
        fact.downloads = downloads
        return fact
    }

    static func event(
        _ kind: SubscriptionEventKind, _ quantity: Int, back: Int = 0, territory: String = "BR", product: PricingProduct = annual,
        keepsID: Bool = true
    ) -> SubscriptionEventFact {
        SubscriptionEventFact(
            day: through.adding(-back), appID: appID, kind: kind, subscription: product.name, territory: territory, device: "iPhone",
            quantity: quantity, subscriptionID: keepsID ? product.id : nil
        )
    }

    static func proceeds(_ amount: Decimal, back: Int = 0, territory: String = "BR", product: PricingProduct = annual) -> SubscriberFact {
        SubscriberFact(
            day: through.adding(-back), appID: appID, subscription: product.name, territory: territory, charges: 1, proceeds: amount,
            subscriptionID: product.id
        )
    }

    /// Every one of the 200 days through `through` read from Sales and
    /// Trends, most of them empty (Apple's 404).
    static let allDays = Set(through.adding(-199).number...through.number)

    static func input(
        engagement: [EngagementFact] = [],
        events: [SubscriptionEventFact] = [],
        subscribers: [SubscriberFact] = [],
        active: [ActiveSubscriptionsFact] = [],
        salesDays: Set<Int> = allDays,
        state: SalesState = .ready,
        usesSalesData: Bool = true
    ) -> PricingSalesInput {
        PricingSalesInput(
            engagement: engagement, events: events, subscribers: subscribers, active: active, salesDays: salesDays,
            salesState: state, usesSalesData: usesSalesData
        )
    }

    static func reader(_ input: PricingSalesInput) -> PricingSalesReader {
        PricingSalesReader(input: input)
    }
}
