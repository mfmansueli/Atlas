//
//  OfferCodeOfferEligibility.swift
//  Atlas
//

import Foundation

/// What happens to the introductory offer of a new subscriber who
/// redeems an offer code: App Store Connect's `SubscriptionOfferEligibility`.
enum OfferCodeOfferEligibility: String, CaseIterable, Hashable, Sendable {
    /// They get the code's offer, then still the introductory offer.
    case stackWithIntroOffers = "STACK_WITH_INTRO_OFFERS"
    /// The code's offer takes the introductory offer's place.
    case replaceIntroOffers = "REPLACE_INTRO_OFFERS"

    var title: String {
        switch self {
        case .stackWithIntroOffers: String(localized: "Then the introductory offer too")
        case .replaceIntroOffers: String(localized: "In place of the introductory offer")
        }
    }
}
