//
//  ExistingWinBackOffer.swift
//  Atlas
//

import Foundation

/// A win-back offer a subscription has in App Store Connect
/// (`GET /v1/subscriptions/{id}/winBackOffers`), with where it runs and
/// its US price.
struct ExistingWinBackOffer: Identifiable, Hashable, Sendable {
    var id: String
    var referenceName: String
    var offerID: String
    var mode: OfferPaymentMode
    var duration: IntroductoryOfferDuration
    var periodCount: Int
    var settings: WinBackOfferSettings
    var prices = ExistingOfferPrices()

    /// `GET` the subscription's win-back offers.
    static func listPath(subscriptionID: String) -> String {
        "/v1/subscriptions/\(subscriptionID)/winBackOffers?fields%5BwinBackOffers%5D=referenceName,offerId,duration,offerMode,"
            + "periodCount,customerEligibilityPaidSubscriptionDurationInMonths,customerEligibilityTimeSinceLastSubscribedInMonths,"
            + "customerEligibilityWaitBetweenOffersInMonths,startDate,endDate,priority,promotionIntent&limit=200"
    }

    /// One resource of the list; nil when its terms aren't ones Atlas knows.
    init?(resource: [String: Any]) {
        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        guard let id = resource["id"] as? String,
              let mode = (attributes["offerMode"] as? String).flatMap(OfferPaymentMode.init(apiValue:)),
              let duration = (attributes["duration"] as? String).flatMap(IntroductoryOfferDuration.init(rawValue:)),
              let settings = WinBackOfferSettings(attributes: attributes)
        else { return nil }
        self.id = id
        referenceName = attributes["referenceName"] as? String ?? ""
        offerID = attributes["offerId"] as? String ?? ""
        self.mode = mode
        self.duration = duration
        periodCount = attributes["periodCount"] as? Int ?? 1
        self.settings = settings
    }

    init(
        id: String, referenceName: String, offerID: String, mode: OfferPaymentMode, duration: IntroductoryOfferDuration,
        periodCount: Int = 1, settings: WinBackOfferSettings, prices: ExistingOfferPrices = ExistingOfferPrices()
    ) {
        self.id = id
        self.referenceName = referenceName
        self.offerID = offerID
        self.mode = mode
        self.duration = duration
        self.periodCount = periodCount
        self.settings = settings
        self.prices = prices
    }

    var terms: OfferTerms {
        OfferTerms(mode: mode, duration: duration, numberOfPeriods: periodCount, price: prices.usPrice, territories: .chosen(prices.territoryIDs))
    }

    /// Whether it has started (its start date stays).
    func hasStarted(today: Date) -> Bool {
        Calendar.current.startOfDay(for: settings.startDate) <= Calendar.current.startOfDay(for: today)
    }

    /// Whether it has ended.
    func hasEnded(today: Date) -> Bool {
        settings.endDate.map { Calendar.current.startOfDay(for: $0) < Calendar.current.startOfDay(for: today) } ?? false
    }

    /// The Offers tab's row and detail.
    func subscriptionOffer(subscriptionPrice: Decimal?) -> SubscriptionOffer {
        SubscriptionOffer(
            id: Self.offerID(id),
            kind: .winBack,
            name: referenceName.isEmpty ? terms.summary : referenceName,
            eligibility: "\(settings.eligibility.summary) · \(settings.datesTitle)",
            paymentMode: mode,
            duration: terms.durationTitle,
            rule: "\(terms.summary) · \(prices.territoriesTitle)",
            priceShare: terms.priceShare(of: subscriptionPrice)
        )
    }

    /// `winBack.<id>`: the Offers tab's id for it.
    static func offerID(_ id: String) -> SubscriptionOffer.ID {
        "winBack.\(id)"
    }
}
