//
//  SubscriptionOfferProblem.swift
//  Atlas
//

import Foundation

/// Why a promotional offer, win-back offer or offer code (or a custom code
/// or one-time codes for one) can't be created or changed as it is: its
/// sheet shows it, and `propose_promotional_offer`, `propose_win_back_offer`
/// and `propose_offer_code` refuse with it.
enum SubscriptionOfferProblem: Hashable, Sendable {
    /// What the terms break, as an introductory offer's would.
    case terms(IntroductoryOfferProblem)
    /// The US price goes in `price`, not among the prices set apart.
    case basePriceSetApart
    case pricedOutsideTerritories([String])
    case invalidTerritoryPrices([String])
    /// A reference name or offer code name, by what the sheet calls it.
    case missingName(String)
    case nameTooLong(String, limit: Int)
    /// An identifier (`offerCode`, `offerId`) by its label.
    case invalidIdentifier(String)
    case identifierTaken(String, value: String)
    case tooMany(OfferKind, limit: Int)
    /// A new subscription waiting in Review & Push: push it first.
    case subscriptionNotCreated
    case noCustomerEligibility
    case invalidEligibilityMonths(String, range: ClosedRange<Int>)
    case sinceLastSubscribedReversed
    case startsInThePast
    case endsBeforeStart
    case invalidCustomCode
    case customCodeTaken(String)
    case customCodeGuideline(String)
    case numberOfCodesOutOfRange(ClosedRange<Int>)
    case expiresInThePast
    /// Deactivated already, or gone.
    case notActive
    case nothingChanged

    var message: String {
        switch self {
        case let .terms(problem):
            return problem.message
        case .basePriceSetApart:
            return String(localized: "The United States’ price is the offer’s price; set the other countries or regions apart.")
        case let .pricedOutsideTerritories(ids):
            return String(localized: "\(ids.formatted(.list(type: .and))) priced apart but not among the offer’s countries or regions.")
        case let .invalidTerritoryPrices(ids):
            return String(localized: "Enter \(ids.formatted(.list(type: .and)))’s price above zero, with up to two decimals.")
        case let .missingName(label):
            return String(localized: "Enter the \(label).")
        case let .nameTooLong(label, limit):
            return String(localized: "The \(label) holds up to \(limit) characters.")
        case let .invalidIdentifier(label):
            return String(localized: "The \(label) takes letters, digits, “_” and “.”, up to 64 characters, and can’t be changed later.")
        case let .identifierTaken(label, value):
            return String(localized: "The subscription has an offer with the \(label) “\(value)” already.")
        case let .tooMany(kind, limit):
            return String(localized: "A subscription has up to \(limit) active \(kind.groupTitle.lowercased()).")
        case .subscriptionNotCreated:
            return String(localized: "The subscription waits in Review & Push. Push it first, then add the offer.")
        case .noCustomerEligibility:
            return String(localized: "Choose who can redeem it: new, active or expired subscribers.")
        case let .invalidEligibilityMonths(label, range):
            return String(localized: "\(label) is \(range.lowerBound) to \(range.upperBound) months.")
        case .sinceLastSubscribedReversed:
            return String(localized: "The shortest time since they last subscribed comes before the longest.")
        case .startsInThePast:
            return String(localized: "The offer can’t start before today.")
        case .endsBeforeStart:
            return String(localized: "The offer ends after it starts.")
        case .invalidCustomCode:
            return String(localized: "A custom code takes letters and digits only, up to 64 characters.")
        case let .customCodeTaken(code):
            return String(localized: "The app has the custom code “\(code)” already.")
        case let .customCodeGuideline(reason):
            return reason
        case let .numberOfCodesOutOfRange(range):
            return String(localized: "Enter \(range.lowerBound.formatted()) to \(range.upperBound.formatted()) codes.")
        case .expiresInThePast:
            return String(localized: "The codes expire after today.")
        case .notActive:
            return String(localized: "It isn’t active in App Store Connect any more.")
        case .nothingChanged:
            return String(localized: "Nothing changed from what App Store Connect has.")
        }
    }
}
