//
//  WinBackOfferSheet.swift
//  Atlas
//

import SwiftUI

/// New Win-Back Offer… for a subscription App Store Connect has: its
/// reference name and offer ID, the terms, who's eligible, when it runs,
/// its priority and whether Apple promotes it. Add to Review & Push queues
/// it; the push creates it with every price.
struct WinBackOfferSheet: View {
    let subscription: PricingProduct
    let problems: (NewWinBackOffer) -> [SubscriptionOfferProblem]
    let onCancel: () -> Void
    let onAdd: (NewWinBackOffer) -> Void

    @State private var name = ""
    @State private var offerID = ""
    @State private var typedOfferID = false
    @State private var draft = OfferTermsDraft()
    @State private var settings = WinBackOfferSettings(startDate: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
    @State private var showsProblems = false

    private static let id = "pricing.winBackOffer"

    private var current: NewWinBackOffer {
        NewWinBackOffer(referenceName: name, offerID: offerID, terms: draft.terms, settings: settings)
    }

    var body: some View {
        OfferSheetChrome(
            title: String(localized: "Win-back offer"),
            detail: String(localized: """
            For people who used to subscribe to \(subscription.name): Apple shows it in your app, in Settings and, if you \
            like, on the App Store. It waits in Review & Push; nothing changes in App Store Connect until you push.
            """),
            footnote: String(localized: "Apple shows people the win-back offers they’re eligible for."),
            identifier: Self.id,
            problems: problems(current),
            showsProblems: $showsProblems,
            onCancel: onCancel,
            onAdd: { onAdd(current) },
            content: {
                Section {
                    TextField("Reference name", text: $name, prompt: Text("We miss you"))
                        .accessibilityIdentifier("\(Self.id).name")
                        .onChange(of: name) {
                            if !typedOfferID { offerID = SubscriptionOfferRules.identifier(from: name) }
                        }
                    TextField("Offer ID", text: Binding {
                        offerID
                    } set: {
                        offerID = $0
                        typedOfferID = true
                    }, prompt: Text(verbatim: "we_miss_you"))
                        .accessibilityIdentifier("\(Self.id).offerID")
                } header: {
                    Text("Name")
                } footer: {
                    Text("Only you see the name and the offer ID; your app can ask StoreKit for the offer by its ID.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
                OfferTermsFields(draft: $draft, period: subscription.period ?? .oneMonth, identifier: Self.id)
                WinBackSettingsFields(settings: $settings, identifier: Self.id)
            }
        )
    }
}
