//
//  PurchaseExtras.swift
//  Atlas
//

import Foundation

/// What a product has in App Store Connect beside its prices: a
/// subscription's introductory offers (one per territory), promotional
/// offers, win-back offers and offer codes, an in-app purchase's offer
/// codes, and either's App Review screenshot.
struct PurchaseExtras: Hashable, Sendable {
    var introductoryOffers: [ExistingIntroductoryOffer] = []
    var promotionalOffers: [ExistingPromotionalOffer] = []
    var winBackOffers: [ExistingWinBackOffer] = []
    var offerCodes: [ExistingOfferCode] = []
    /// An in-app purchase's offer codes.
    var inAppPurchaseOfferCodes: [ExistingInAppPurchaseOfferCode] = []
    /// False when the promotional offers, win-back offers and offer codes
    /// (an in-app purchase's offer codes) couldn't be read.
    var offersRead = false
    var reviewScreenshot: PurchaseReviewScreenshotState = .missing

    /// The offers grouped by their terms.
    var introductoryTerms: [ExistingIntroductoryOffer.Terms] {
        ExistingIntroductoryOffer.terms(of: introductoryOffers)
    }

    /// "Free for 1 week · 175 countries or regions", when it has one.
    var introductorySummary: String? {
        let terms = introductoryTerms
        guard !terms.isEmpty else { return nil }
        return terms.map(\.summary).joined(separator: "; ")
    }
}
