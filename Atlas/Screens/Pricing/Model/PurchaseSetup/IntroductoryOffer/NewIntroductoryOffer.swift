//
//  NewIntroductoryOffer.swift
//  Atlas
//

import Foundation

/// An introductory offer to create for a subscription, as Add Introductory
/// Offer… or an assistant's `propose_introductory_offer` fills it in: new
/// subscribers get a free trial, or pay a lower price per period (pay as
/// you go) or once (pay up front). The push creates it in every territory
/// it runs in, with Apple's price point equalized with the US price for a
/// paid one (`IntroductoryOfferEverywhere`).
struct NewIntroductoryOffer: Hashable, Sendable {
    var mode: OfferPaymentMode
    var duration: IntroductoryOfferDuration
    var numberOfPeriods = 1
    /// What a paid offer costs in the United States, in US dollars: per
    /// period for pay as you go, once for pay up front. Nil for a free trial.
    var price: Decimal?
    var territories: IntroductoryOfferTerritories = .everywhere
    /// The first and last day it runs; nil starts it at once and keeps it.
    var startDate: Date?
    var endDate: Date?

    /// The attributes' `numberOfPeriods`: one for a free trial or pay up
    /// front offer.
    var sentPeriods: Int {
        mode == .payAsYouGo ? numberOfPeriods : 1
    }

    /// "$0.99" for a paid offer.
    var formattedPrice: String? {
        guard mode != .freeTrial else { return nil }
        return price.map { CurrencyFormat.forCurrency("USD").format($0) }
    }

    /// "1-week free trial", "$0.99 a month for 3 months", "$4.99 for 3 months".
    var summary: String {
        let price = formattedPrice ?? ""
        switch mode {
        case .freeTrial:
            return String(localized: "Free for \(duration.title)")
        case .payAsYouGo:
            let total = numberOfPeriods == 1 ? duration.title : String(localized: "\(numberOfPeriods) × \(duration.title)")
            return String(localized: "\(price) a \(duration.unitTitle) for \(total)")
        case .payUpFront:
            return String(localized: "\(price) for \(duration.title)")
        }
    }

    /// `2026-12-01`: App Store Connect's dates, in this Mac's calendar day.
    static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func day(from text: String) -> Date? {
        dayFormatter.date(from: text.trimmingCharacters(in: .whitespaces))
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
