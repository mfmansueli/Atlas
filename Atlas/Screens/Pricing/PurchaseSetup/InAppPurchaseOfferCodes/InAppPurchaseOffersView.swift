//
//  InAppPurchaseOffersView.swift
//  Atlas
//

import SwiftUI

/// An in-app purchase's Offers tab: its offer codes in App Store Connect,
/// the offer code changes waiting in Review & Push, and the selected one's
/// actions (`InAppPurchaseOfferCodeActions`) and details. New Offer Code…
/// adds one.
struct InAppPurchaseOffersView: View {
    @Bindable var viewModel: PricingViewModel
    let matrix: PriceMatrixModel

    private var purchase: PricingProduct { matrix.product }

    var body: some View {
        Group {
            switch viewModel.offers {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(offers) where offers.isEmpty && viewModel.queuedInAppPurchaseOfferCodes.isEmpty:
                ContentUnavailableView {
                    Label("No offer codes yet", systemImage: "tag")
                } description: {
                    Text("People redeem an offer code to get \(purchase.name) for free or at a lower price: in the App Store, in your app or by link.")
                } actions: {
                    newOfferCodeButton
                        .fixedSize(horizontal: true, vertical: false)
                }
                .accessibilityIdentifier("pricing.iapOffers.none")
            case let .loaded(offers):
                HStack(spacing: 0) {
                    list(offers)
                        .frame(width: 250)
                    Divider()
                    if let code = viewModel.inAppPurchaseOfferCode(id: viewModel.selectedOfferID, of: purchase) {
                        VStack(spacing: 0) {
                            InAppPurchaseOfferCodeActions(viewModel: viewModel, purchase: purchase, code: code)
                            InAppPurchaseOfferCodeDetail(code: code, purchase: purchase, rows: matrix.rows.sorted(by: PricingRow.defaultOrder))
                        }
                    } else {
                        Text("Select an offer code")
                            .foregroundStyle(Palette.label2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            case let .failed(message):
                ContentUnavailableView {
                    Label("Offer codes couldn’t load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: purchase.id) { await viewModel.loadOffers() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.offers")
    }

    private var newOfferCodeButton: some View {
        let canAdd = viewModel.canAddInAppPurchaseOfferCodes(to: purchase)
        return Button {
            viewModel.openInAppPurchaseOffer(.newOfferCode(purchase))
        } label: {
            Label("New Offer Code…", systemImage: "plus")
        }
        .controlSize(.regular)
        .buttonBorderShape(.capsule)
        .disabled(!canAdd)
        .help(canAdd
            ? String(localized: "The in-app purchase for free or at a lower price with a code, queued in Review & Push.")
            : String(localized: "Atlas couldn’t read this in-app purchase’s offer codes from App Store Connect yet."))
        .accessibilityIdentifier("pricing.iapOffers.new")
    }

    private func list(_ offers: [SubscriptionOffer]) -> some View {
        List(selection: $viewModel.selectedOfferID) {
            if !offers.isEmpty {
                Section(OfferKind.offerCode.groupTitle) {
                    ForEach(offers) { offer in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(offer.name)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(offer.eligibility)
                                .font(.subheadline)
                                .foregroundStyle(Palette.label2)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 2)
                        .tag(offer.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("pricing.offer.\(offer.id)")
                    }
                }
            }
            let queued = viewModel.queuedInAppPurchaseOfferCodes
            if !queued.isEmpty {
                Section("Waiting in Review & Push") {
                    ForEach(queued) { change in
                        QueuedSubscriptionOfferRow(change: change)
                            .selectionDisabled()
                    }
                }
            }
            newOfferCodeButton
                .padding(.top, Spacing.xSmall)
                .selectionDisabled()
        }
        // Rows hold row-sized (24 pt) controls.
        .controlSize(.regular)
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("pricing.iapOffers.list")
    }
}
