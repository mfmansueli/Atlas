//
//  NewSubscriptionOfferMenu.swift
//  Atlas
//

import SwiftUI

/// The Offers tab's New Offer menu: a promotional offer, a win-back offer
/// or an offer code for a subscription App Store Connect has, once Atlas
/// has read its offers (so it knows which names are taken).
struct NewSubscriptionOfferMenu: View {
    @Bindable var viewModel: PricingViewModel
    let product: PricingProduct

    var body: some View {
        let canAdd = viewModel.canAddOffers(to: product)
        Menu {
            Button("Promotional Offer…") { viewModel.open(.newPromotional(product)) }
                .accessibilityIdentifier("pricing.offers.newPromotional")
            Button("Win-Back Offer…") { viewModel.open(.newWinBack(product)) }
                .accessibilityIdentifier("pricing.offers.newWinBack")
            Button("Offer Code…") { viewModel.open(.newOfferCode(product)) }
                .accessibilityIdentifier("pricing.offers.newOfferCode")
        } label: {
            Label("New Offer", systemImage: "plus")
        }
        .fixedSize()
        .controlSize(.regular)
        .buttonBorderShape(.capsule)
        .disabled(!canAdd)
        .help(canAdd
            ? String(localized: "Adds a promotional offer, win-back offer or offer code to Review & Push.")
            : String(localized: "Offers haven’t loaded from App Store Connect yet."))
        .accessibilityIdentifier("pricing.offers.newMenu")
    }
}
