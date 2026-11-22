//
//  PricingOffersView.swift
//  Atlas
//

import SwiftUI

/// The Offers tab: the subscription's offers grouped by kind, and the
/// selected one's prices, which follow each territory's subscription price.
struct PricingOffersView: View {
    @Bindable var viewModel: PricingViewModel
    let matrix: PriceMatrixModel

    var body: some View {
        Group {
            switch viewModel.offers {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(offers) where offers.isEmpty:
                ContentUnavailableView {
                    Label("No offers yet", systemImage: "tag")
                } description: {
                    Text("Introductory, promotional and win-back offers and offer codes for this subscription appear here.")
                } actions: {
                    addIntroductoryOfferButton
                }
                .accessibilityIdentifier("pricing.offers.none")
            case let .loaded(offers):
                HStack(spacing: 0) {
                    list(offers)
                        .frame(width: 250)
                    Divider()
                    if let offer = viewModel.selectedOffer {
                        OfferDetailView(offer: offer, prices: matrix.offerPrices(for: offer))
                    } else {
                        Text("Select an offer")
                            .foregroundStyle(Palette.label2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            case let .failed(message):
                ContentUnavailableView {
                    Label("Offers couldn’t load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: matrix.product.id) { await viewModel.loadOffers() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.offers")
    }

    /// Add Introductory Offer… for a subscription without one; other
    /// offers are edited in App Store Connect for now.
    private var addIntroductoryOfferButton: some View {
        let canAdd = viewModel.canAddIntroductoryOffer(to: matrix.product)
            && viewModel.offers.value?.contains { $0.kind == .introductory } != true
        return Button {
            viewModel.openIntroductoryOffer(for: matrix.product)
        } label: {
            Label("Add Introductory Offer…", systemImage: "plus")
        }
        .controlSize(.small)
        .buttonBorderShape(.capsule)
        .disabled(!canAdd)
        .help(canAdd
            ? String(localized: "A free trial or a lower price for new subscribers, queued in Review & Push.")
            : String(localized: "It has an introductory offer. Edit other offers in App Store Connect for now."))
        .accessibilityIdentifier("pricing.offers.new")
    }

    private func list(_ offers: [SubscriptionOffer]) -> some View {
        List(selection: $viewModel.selectedOfferID) {
            ForEach(OfferKind.allCases, id: \.self) { kind in
                let group = offers.filter { $0.kind == kind }
                if !group.isEmpty {
                    Section(kind.groupTitle) {
                        ForEach(group) { offer in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(offer.name)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                Text(offer.eligibility)
                                    .font(.caption)
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
            }
            addIntroductoryOfferButton
                .padding(.top, Spacing.xSmall)
                .selectionDisabled()
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("pricing.offers.list")
    }
}
