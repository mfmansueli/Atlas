//
//  OfferTermsFields.swift
//  Atlas
//

import SwiftUI

/// The terms sections the offer sheets share, as Add Introductory Offer…
/// lays them out: the type, duration and periods; the US price (equalized
/// everywhere else) with any country or region priced apart; and where it
/// runs. `fixesTerms` shows the type and duration without changing them,
/// for an offer App Store Connect has.
struct OfferTermsFields: View {
    @Binding var draft: OfferTermsDraft
    let period: SubscriptionPeriod
    /// `pricing.promotionalOffer`, for the controls' identifiers.
    let identifier: String
    var fixesTerms = false

    var body: some View {
        termsSection
        if draft.mode != .freeTrial { priceSection }
        territorySection
    }

    private var termsSection: some View {
        Section {
            if fixesTerms {
                LabeledContent("Type", value: draft.mode.title)
                LabeledContent("Duration", value: draft.terms.durationTitle)
            } else {
                Picker("Type", selection: $draft.mode) {
                    ForEach(OfferPaymentMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .accessibilityIdentifier("\(identifier).mode")
                Picker(draft.mode == .payAsYouGo ? "Each period" : "Duration", selection: $draft.duration) {
                    ForEach(draft.mode.allowedDurations(for: period), id: \.self) { duration in
                        Text(duration.title).tag(duration)
                    }
                }
                .accessibilityIdentifier("\(identifier).duration")
                if draft.mode == .payAsYouGo {
                    Stepper(value: $draft.numberOfPeriods, in: draft.mode.allowedPeriods(for: period)) {
                        Text("For \(draft.numberOfPeriods) periods")
                    }
                    .accessibilityIdentifier("\(identifier).periods")
                }
            }
        } header: {
            Text("Offer")
        } footer: {
            note(fixesTerms
                ? String(localized: "An offer’s type and duration can’t change. Delete it and add another.")
                : draft.terms.summary)
        }
        .onChange(of: draft.mode) { draft.fit(period: period) }
        .onAppear { if !fixesTerms { draft.fit(period: period) } }
    }

    private var priceSection: some View {
        Section {
            LabeledContent {
                HStack(spacing: Spacing.xSmall) {
                    TextField("Price", text: $draft.priceText, prompt: Text(verbatim: "0.99"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                        .accessibilityIdentifier("\(identifier).price")
                    Text(verbatim: "USD")
                        .foregroundStyle(Palette.label2)
                }
            } label: {
                Text(draft.mode == .payAsYouGo ? "US price per period" : "Price (United States)")
            }
            OfferTerritoryPricesEditor(prices: $draft.territoryPriceTexts, identifier: identifier)
        } header: {
            Text("Price")
        } footer: {
            note(String(localized: "Other countries and regions get Apple’s automatic price unless you set one here."))
        }
    }

    private var territorySection: some View {
        Section {
            Picker("Where", selection: $draft.choosesTerritories) {
                Text("Everywhere it’s sold").tag(false)
                Text("Chosen countries or regions").tag(true)
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("\(identifier).where")
            if draft.choosesTerritories {
                IntroductoryOfferTerritoryList(chosen: $draft.chosen)
                    .frame(height: 180)
            }
        } header: {
            Text("Countries or regions")
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
