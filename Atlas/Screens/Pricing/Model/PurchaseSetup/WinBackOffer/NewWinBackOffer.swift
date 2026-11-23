//
//  NewWinBackOffer.swift
//  Atlas
//

import Foundation

/// A win-back offer to create for a subscription, as New Win-Back Offer…
/// or an assistant's `propose_win_back_offer` fills it in: free time or a
/// lower price Apple shows people who used to subscribe (in the app, in
/// Settings and, when promoted, on the App Store), from a start date. Its
/// reference name and offer ID are only seen by the developer and can't
/// change; its eligibility, dates, priority and promotion can
/// (`WinBackOfferSettings`).
struct NewWinBackOffer: Hashable, Sendable {
    /// `referenceName`.
    var referenceName: String
    /// `offerId`: the identifier the app's code can ask StoreKit for.
    var offerID: String
    var terms: OfferTerms
    var settings: WinBackOfferSettings

    var trimmedName: String {
        referenceName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOfferID: String {
        offerID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The `attributes` App Store Connect creates it with.
    var attributes: [String: Any] {
        var attributes: [String: Any] = [
            "referenceName": trimmedName,
            "offerId": trimmedOfferID,
            "duration": terms.duration.rawValue,
            "offerMode": terms.mode.apiValue,
            "periodCount": terms.sentPeriods,
        ]
        attributes.merge(settings.attributes) { $1 }
        return attributes
    }

    init(referenceName: String, offerID: String, terms: OfferTerms, settings: WinBackOfferSettings) {
        self.referenceName = referenceName
        self.offerID = offerID
        self.terms = terms
        self.settings = settings
    }

    /// The offer a queued create carries back; nil for another request.
    init?(_ write: SubscriptionOfferWrite) {
        let attributes = write.attributes
        guard write.resource == .winBack, write.isCreate,
              let name = attributes["referenceName"] as? String, let offerID = attributes["offerId"] as? String,
              let mode = (attributes["offerMode"] as? String).flatMap(OfferPaymentMode.init(apiValue:)),
              let duration = (attributes["duration"] as? String).flatMap(IntroductoryOfferDuration.init(rawValue:)),
              let settings = WinBackOfferSettings(attributes: attributes)
        else { return nil }
        let terms = OfferTerms(mode: mode, duration: duration, numberOfPeriods: attributes["periodCount"] as? Int ?? 1)
        self.init(referenceName: name, offerID: offerID, terms: write.plan.applied(to: terms), settings: settings)
    }
}
