//
//  NewInAppPurchaseOfferCode.swift
//  Atlas
//

import Foundation

/// An offer code to create for an in-app purchase, as New Offer Code… or an
/// assistant's `propose_in_app_purchase_offer_code` fills it in: the
/// purchase for free or at a lower price, redeemed with a code (in the App
/// Store, in the app or by link) by the people chosen. The push creates it
/// with its prices, then the custom code and one-time codes it comes with,
/// if any. Its name is only seen by the developer; the custom code is what
/// customers type.
struct NewInAppPurchaseOfferCode: Hashable, Sendable {
    var name: String
    var eligibilities: [InAppPurchaseOfferCodeEligibility] = [.nonSpender]
    var terms: InAppPurchaseOfferTerms
    var customCode: NewCustomCode?
    var oneTimeCodes: NewOneTimeCodes?

    init(
        name: String, eligibilities: [InAppPurchaseOfferCodeEligibility] = [.nonSpender], terms: InAppPurchaseOfferTerms,
        customCode: NewCustomCode? = nil, oneTimeCodes: NewOneTimeCodes? = nil
    ) {
        self.name = name
        self.eligibilities = eligibilities
        self.terms = terms
        self.customCode = customCode
        self.oneTimeCodes = oneTimeCodes
    }

    /// The offer code a queued create carries back (without its codes);
    /// nil for another request.
    init?(_ write: InAppPurchaseOfferCodeWrite) {
        guard let name = write.name else { return nil }
        let eligibilities = (write.attributes["customerEligibilities"] as? [String] ?? []).compactMap(InAppPurchaseOfferCodeEligibility.init(rawValue:))
        self.init(name: name, eligibilities: eligibilities, terms: InAppPurchaseOfferTerms(plan: write.plan))
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The `attributes` App Store Connect creates it with.
    var attributes: [String: Any] {
        [
            "name": trimmedName,
            "customerEligibilities": InAppPurchaseOfferCodeEligibility.sorted(eligibilities).map(\.rawValue),
        ]
    }

    /// "People who never bought · Free".
    var summary: String {
        "\(InAppPurchaseOfferCodeEligibility.title(of: eligibilities)) · \(terms.summary)"
    }
}
