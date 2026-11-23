//
//  PromotionalOfferPricesSheet.swift
//  Atlas
//

import SwiftUI

/// Change Prices… for a promotional offer App Store Connect has: its type
/// and duration stay (Apple doesn't let them change); its US price, the
/// countries or regions priced apart and where it runs change. The push
/// replaces its prices.
struct PromotionalOfferPricesSheet: View {
    let subscription: PricingProduct
    let offer: ExistingPromotionalOffer
    let problems: (OfferTerms) -> [SubscriptionOfferProblem]
    let onCancel: () -> Void
    let onAdd: (OfferTerms) -> Void

    @State private var draft: OfferTermsDraft
    @State private var showsProblems = false

    private static let id = "pricing.promotionalPrices"

    init(
        subscription: PricingProduct, offer: ExistingPromotionalOffer, problems: @escaping (OfferTerms) -> [SubscriptionOfferProblem],
        onCancel: @escaping () -> Void, onAdd: @escaping (OfferTerms) -> Void
    ) {
        self.subscription = subscription
        self.offer = offer
        self.problems = problems
        self.onCancel = onCancel
        self.onAdd = onAdd
        _draft = State(initialValue: OfferTermsDraft(offer.terms))
    }

    var body: some View {
        OfferSheetChrome(
            title: String(localized: "Prices of “\(offer.name)”"),
            detail: String(localized: "The push replaces the offer’s prices everywhere it runs. People who redeemed it keep what they pay."),
            footnote: String(localized: "Identifier: \(offer.identifier)"),
            identifier: Self.id,
            problems: problems(draft.terms),
            showsProblems: $showsProblems,
            onCancel: onCancel,
            onAdd: { onAdd(draft.terms) },
            content: {
                OfferTermsFields(draft: $draft, period: subscription.period ?? .oneMonth, identifier: Self.id, fixesTerms: true)
            }
        )
    }
}
