//
//  PromotionalOfferSheet.swift
//  Atlas
//

import SwiftUI

/// New Promotional Offer… for a subscription App Store Connect has: its
/// reference name, the identifier the app's code passes to StoreKit, and
/// the terms (a free period or a lower price, US price equalized everywhere
/// else, some countries or regions priced apart). Add to Review & Push
/// queues it; the push creates it with every price.
struct PromotionalOfferSheet: View {
    let subscription: PricingProduct
    let problems: (NewPromotionalOffer) -> [SubscriptionOfferProblem]
    let onCancel: () -> Void
    let onAdd: (NewPromotionalOffer) -> Void

    @State private var name = ""
    @State private var identifier = ""
    /// Until the identifier is typed, it follows the name.
    @State private var typedIdentifier = false
    @State private var draft = OfferTermsDraft()
    @State private var showsProblems = false

    private static let id = "pricing.promotionalOffer"

    private var current: NewPromotionalOffer {
        NewPromotionalOffer(name: name, identifier: identifier, terms: draft.terms)
    }

    var body: some View {
        OfferSheetChrome(
            title: String(localized: "Promotional offer"),
            detail: String(localized: """
            For current and past \(subscription.name) subscribers, offered by your app with StoreKit. Nothing changes until you push.
            """),
            footnote: String(localized: "Up to 10 per subscription. Your app offers it by its identifier."),
            identifier: Self.id,
            problems: problems(current),
            showsProblems: $showsProblems,
            onCancel: onCancel,
            onAdd: { onAdd(current) },
            content: {
                Section {
                    TextField("Reference name", text: $name, prompt: Text("Come back for half price"))
                        .accessibilityIdentifier("\(Self.id).name")
                        .onChange(of: name) {
                            if !typedIdentifier { identifier = SubscriptionOfferRules.identifier(from: name) }
                        }
                    TextField("Offer identifier", text: Binding {
                        identifier
                    } set: {
                        identifier = $0
                        typedIdentifier = true
                    }, prompt: Text(verbatim: "come_back_half"))
                        .accessibilityIdentifier("\(Self.id).identifier")
                } header: {
                    Text("Name")
                } footer: {
                    Text("Only you see the name. Use the identifier your app’s code passes to StoreKit.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
                OfferTermsFields(draft: $draft, period: subscription.period ?? .oneMonth, identifier: Self.id)
            }
        )
    }
}
