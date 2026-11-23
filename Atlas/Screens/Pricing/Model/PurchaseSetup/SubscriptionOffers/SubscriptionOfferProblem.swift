//
//  SubscriptionOfferProblem.swift
//  Atlas
//

import Foundation

/// Why a promotional offer, win-back offer or offer code (or a custom code
/// or one-time codes for one) can't be created or changed as it is: its
/// sheet shows it, and `propose_promotional_offer`, `propose_win_back_offer`,
/// `propose_offer_code` and `propose_in_app_purchase_offer_code` refuse
/// with it.
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
    // An in-app purchase's offer code.
    /// A new in-app purchase waiting in Review & Push: push it first.
    case inAppPurchaseNotCreated
    case inAppPurchaseOfferCodeNameTaken(String)
    case tooManyInAppPurchaseOfferCodes(limit: Int)
    case noSpenderEligibility
    /// Zero (free) or more, with at most two decimals.
    case invalidInAppPurchaseOfferPrice
    /// At or above the in-app purchase's own US price.
    case notBelowPurchasePrice(String)

    var message: String {
        switch self {
        case let .terms(problem):
            problem.message
        case .basePriceSetApart:
            String(localized: "The United States’ price is the offer’s price; set the other countries or regions apart.")
        case let .pricedOutsideTerritories(ids):
            String(localized: "\(ids.formatted(.list(type: .and))) priced apart but not among the offer’s countries or regions.")
        case let .invalidTerritoryPrices(ids):
            String(localized: "Enter \(ids.formatted(.list(type: .and)))’s price above zero, with up to two decimals.")
        case let .missingName(label):
            String(localized: "Enter the \(label).")
        case let .nameTooLong(label, limit):
            String(localized: "The \(label) holds up to \(limit) characters.")
        case let .invalidIdentifier(label):
            String(localized: "The \(label) takes letters, digits, “_” and “.”, up to 64 characters, and can’t be changed later.")
        case let .identifierTaken(label, value):
            String(localized: "Another offer already uses the \(label) “\(value)”.")
        case let .tooMany(kind, limit):
            String(localized: "A subscription has up to \(limit) active \(kind.groupTitle.lowercased()).")
        case .subscriptionNotCreated:
            String(localized: "The subscription waits in Review & Push. Push it first, then add the offer.")
        case .noCustomerEligibility:
            String(localized: "Choose who can redeem it: new, active or expired subscribers.")
        case let .invalidEligibilityMonths(label, range):
            String(localized: "\(label) is \(range.lowerBound) to \(range.upperBound) months.")
        case .sinceLastSubscribedReversed:
            String(localized: "The shortest time since they last subscribed comes before the longest.")
        case .startsInThePast:
            String(localized: "The offer can’t start before today.")
        case .endsBeforeStart:
            String(localized: "The offer ends after it starts.")
        case .invalidCustomCode:
            String(localized: "A custom code takes letters and digits only, up to 64 characters.")
        case let .customCodeTaken(code):
            String(localized: "The app has the custom code “\(code)” already.")
        case let .customCodeGuideline(reason):
            reason
        case let .numberOfCodesOutOfRange(range):
            String(localized: "Enter \(range.lowerBound.formatted()) to \(range.upperBound.formatted()) codes.")
        case .expiresInThePast:
            String(localized: "The codes expire after today.")
        case .notActive:
            String(localized: "It isn’t active in App Store Connect any more.")
        case .nothingChanged:
            String(localized: "Nothing changed from what App Store Connect has.")
        case .inAppPurchaseNotCreated:
            String(localized: "The in-app purchase waits in Review & Push. Push it first, then add the offer code.")
        case let .inAppPurchaseOfferCodeNameTaken(name):
            String(localized: "Another offer code is already named “\(name)”.")
        case let .tooManyInAppPurchaseOfferCodes(limit):
            String(localized: "An in-app purchase has up to \(limit) active offer codes.")
        case .noSpenderEligibility:
            String(localized: "Choose who can redeem it: people who never bought, who buy now, or who stopped buying.")
        case .invalidInAppPurchaseOfferPrice:
            String(localized: "Enter a price in US dollars: zero for free, or more with up to two decimals.")
        case let .notBelowPurchasePrice(price):
            String(localized: "Set a price below the in-app purchase’s \(price) in the United States.")
        }
    }
}
