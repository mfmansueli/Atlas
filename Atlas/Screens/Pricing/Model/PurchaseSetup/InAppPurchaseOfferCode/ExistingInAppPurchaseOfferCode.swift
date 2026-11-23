//
//  ExistingInAppPurchaseOfferCode.swift
//  Atlas
//

import Foundation

/// An offer code an in-app purchase (consumable, non-consumable or
/// non-renewing subscription) has in App Store Connect
/// (`GET /v2/inAppPurchases/{id}/offerCodes`), with its custom codes,
/// one-time code batches, where it runs and its US price. App Store Connect
/// only lets `active` change.
struct ExistingInAppPurchaseOfferCode: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var eligibilities: [InAppPurchaseOfferCodeEligibility]
    var isActive: Bool
    /// How many codes it has on the App Store, and in the sandbox.
    var productionCodeCount: Int?
    var sandboxCodeCount: Int?
    var customCodes: [ExistingCustomCode] = []
    var oneTimeCodes: [ExistingOneTimeCodes] = []
    var prices = ExistingOfferPrices()

    init?(resource: [String: Any]) {
        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        guard let id = resource["id"] as? String else { return nil }
        self.id = id
        name = attributes["name"] as? String ?? ""
        let eligibilities = attributes["customerEligibilities"] as? [String] ?? []
        self.eligibilities = InAppPurchaseOfferCodeEligibility.sorted(eligibilities.compactMap(InAppPurchaseOfferCodeEligibility.init(rawValue:)))
        isActive = attributes["active"] as? Bool ?? true
        productionCodeCount = attributes["productionCodeCount"] as? Int
        sandboxCodeCount = attributes["sandboxCodeCount"] as? Int
    }

    init(
        id: String, name: String, eligibilities: [InAppPurchaseOfferCodeEligibility], isActive: Bool = true,
        customCodes: [ExistingCustomCode] = [], oneTimeCodes: [ExistingOneTimeCodes] = [], prices: ExistingOfferPrices = ExistingOfferPrices()
    ) {
        self.id = id
        self.name = name
        self.eligibilities = eligibilities
        self.isActive = isActive
        self.customCodes = customCodes
        self.oneTimeCodes = oneTimeCodes
        self.prices = prices
    }

    var terms: InAppPurchaseOfferTerms {
        InAppPurchaseOfferTerms(price: prices.usPrice, territories: .chosen(prices.territoryIDs))
    }

    /// "PODCAST30 · 500 one-time codes", "No codes yet".
    var codesSummary: String {
        var parts: [String] = []
        if !customCodes.isEmpty { parts.append(customCodes.map(\.code).joined(separator: ", ")) }
        let codes = oneTimeCodes.reduce(0) { $0 + $1.numberOfCodes }
        if codes > 0 { parts.append(String(localized: "\(codes.formatted()) one-time codes")) }
        return parts.isEmpty ? String(localized: "No codes yet") : parts.joined(separator: " · ")
    }

    /// Every custom code of `codes`, as customers type them.
    static func customCodes(of codes: [Self]) -> Set<String> {
        Set(codes.flatMap(\.customCodes).map { SubscriptionOfferRules.customCode($0.code) })
    }

    /// The Offers tab's row.
    func subscriptionOffer(purchasePrice: Decimal?) -> SubscriptionOffer {
        var eligibility = InAppPurchaseOfferCodeEligibility.title(of: eligibilities) + " · " + codesSummary
        if !isActive { eligibility += " · " + String(localized: "inactive") }
        return SubscriptionOffer(
            id: Self.offerID(id),
            kind: .offerCode,
            name: name.isEmpty ? terms.summary : name,
            eligibility: eligibility,
            paymentMode: .payUpFront,
            duration: String(localized: "One purchase"),
            rule: "\(terms.summary(purchasePrice: purchasePrice)) · \(prices.territoriesTitle)",
            priceShare: terms.priceShare(of: purchasePrice)
        )
    }

    /// `iapOfferCode.<id>`: the Offers tab's id for it.
    static func offerID(_ id: String) -> SubscriptionOffer.ID {
        "iapOfferCode.\(id)"
    }
}
