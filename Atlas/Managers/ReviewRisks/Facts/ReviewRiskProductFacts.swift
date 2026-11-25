//
//  ReviewRiskProductFacts.swift
//  Atlas
//

import Foundation

/// Subscriptions, in-app purchases and the license agreement, with what
/// the subscription checks read beside them: each language's description
/// as pushed (for a Terms of Use link) and whether a version is being
/// prepared (for products that go with it).
struct ReviewRiskProductFacts: Hashable, Sendable {
    var products: [ReviewRiskProduct] = []
    /// A custom license agreement (EULA) in App Store Connect; false uses
    /// Apple's standard one, nil when it couldn't be read.
    var hasCustomEULA: Bool?
    /// Locale code → the description as pushed. The checks prefer
    /// `ReviewRiskFacts.texts` (it has what waits in Review & Push).
    var descriptions: [String: String] = [:]
    /// The store locales, in App Store Connect's order.
    var locales: [String] = []
    var primaryLocale = "en-US"
    /// The version being prepared ("1.4"); nil when none is.
    var preparedVersion: String?

    init(
        products: [ReviewRiskProduct] = [], hasCustomEULA: Bool? = nil, descriptions: [String: String] = [:], locales: [String] = [],
        primaryLocale: String = "en-US", preparedVersion: String? = nil
    ) {
        self.products = products
        self.hasCustomEULA = hasCustomEULA
        self.descriptions = descriptions
        self.locales = locales
        self.primaryLocale = primaryLocale
        self.preparedVersion = preparedVersion
    }

    /// Auto-renewable subscriptions still sold or on their way.
    var subscriptions: [ReviewRiskProduct] {
        products.filter { $0.isSubscription && !$0.isRemoved }
    }

    /// App Review approved a subscription before: a new one doesn't have
    /// to go with a version.
    var hasApprovedSubscription: Bool {
        products.contains { $0.isSubscription && $0.isApproved }
    }

    var hasApprovedInAppPurchase: Bool {
        products.contains { !$0.isSubscription && $0.isApproved }
    }

    /// The first of its kind goes to App Review with a version.
    func isFirst(_ product: ReviewRiskProduct) -> Bool {
        product.isSubscription ? !hasApprovedSubscription : !hasApprovedInAppPurchase
    }
}
