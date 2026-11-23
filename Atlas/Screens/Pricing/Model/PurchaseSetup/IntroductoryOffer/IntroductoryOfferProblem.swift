//
//  IntroductoryOfferProblem.swift
//  Atlas
//

import Foundation

/// Why an introductory offer can't be created as it is: Add Introductory
/// Offer… shows it, and `propose_introductory_offer` refuses with it.
enum IntroductoryOfferProblem: Hashable, Sendable {
    case durationNotAllowed(OfferPaymentMode, allowed: [IntroductoryOfferDuration])
    case periodsOutOfRange(ClosedRange<Int>)
    case missingPrice
    /// Above zero, with at most two decimals.
    case invalidPrice
    /// A paid offer at or above the subscription's own US price.
    case notBelowSubscriptionPrice(String)
    case noTerritories
    case unknownTerritories([String])
    case endsBeforeStart
    case startsInThePast
    /// The subscription has one already; App Store Connect takes one
    /// introductory offer per territory at a time.
    case alreadyHasOne(String)

    var message: String {
        switch self {
        case let .durationNotAllowed(mode, allowed):
            let names = allowed.map(\.title).formatted(.list(type: .or))
            return String(localized: "A \(mode.title.lowercased()) offer lasts \(names).")
        case let .periodsOutOfRange(range):
            return range.lowerBound == range.upperBound
                ? String(localized: "This offer runs for \(range.lowerBound) period.")
                : String(localized: "A pay as you go offer runs for \(range.lowerBound) to \(range.upperBound) periods.")
        case .missingPrice:
            return String(localized: "Enter the offer’s US price, in US dollars.")
        case .invalidPrice:
            return String(localized: "Enter a price in US dollars, above zero and with up to two decimals.")
        case let .notBelowSubscriptionPrice(price):
            return String(localized: "Set a price below the subscription’s \(price) in the United States.")
        case .noTerritories:
            return String(localized: "Choose at least one country or region.")
        case let .unknownTerritories(ids):
            return String(localized: "App Store Connect has no country or region \(ids.formatted(.list(type: .and))). Use alpha-3 codes, e.g. USA.")
        case .endsBeforeStart:
            return String(localized: "The offer ends after it starts.")
        case .startsInThePast:
            return String(localized: "The offer can’t start before today.")
        case let .alreadyHasOne(summary):
            return String(localized: "It already has an introductory offer (\(summary)). End or delete it in App Store Connect first.")
        }
    }
}
