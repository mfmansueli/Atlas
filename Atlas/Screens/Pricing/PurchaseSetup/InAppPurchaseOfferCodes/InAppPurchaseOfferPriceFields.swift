//
//  InAppPurchaseOfferPriceFields.swift
//  Atlas
//

import SwiftUI

/// New Offer Code…'s price and countries for an in-app purchase: free, or a
/// lower US price (equalized everywhere else) with any country or region
/// priced apart; and where it runs. The typed text lives in an
/// `OfferTermsDraft`, as the subscription offer sheets keep theirs.
struct InAppPurchaseOfferPriceFields: View {
    @Binding var draft: OfferTermsDraft
    @Binding var isFree: Bool
    let purchase: PricingProduct
    /// `pricing.iapOfferCode`, for the controls' identifiers.
    let identifier: String

    /// The terms the fields describe; a price that isn't a number counts as
    /// missing, so the checks name it.
    static func terms(draft: OfferTermsDraft, isFree: Bool) -> InAppPurchaseOfferTerms {
        InAppPurchaseOfferTerms(
            price: isFree ? 0 : NewSubscription.price(from: draft.priceText),
            territories: draft.choosesTerritories ? .chosen(draft.chosen.sorted()) : .everywhere,
            territoryPrices: isFree ? [:] : draft.territoryPriceTexts.mapValues { NewSubscription.price(from: $0) ?? 0 }
        )
    }

    var body: some View {
        priceSection
        territorySection
    }

    private var priceSection: some View {
        Section {
            Picker("Offer", selection: $isFree) {
                Text("Free").tag(true)
                Text("A lower price").tag(false)
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("\(identifier).free")
            if !isFree {
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
                    Text("Price (United States)")
                }
                OfferTerritoryPricesEditor(prices: $draft.territoryPriceTexts, identifier: identifier)
            }
        } header: {
            Text("Price")
        } footer: {
            note(footer)
        }
    }

    private var footer: String {
        let now = purchase.basePriceText.map { String(localized: "\(purchase.name) costs \($0) in the United States. ") } ?? ""
        return isFree
            ? String(localized: "\(now)With a code, it’s free.")
            : String(localized: "\(now)Other countries and regions get Apple’s automatic price unless you set one here.")
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
