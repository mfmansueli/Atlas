//
//  SubscriptionOffersReader.swift
//  Atlas
//

import Foundation

/// Reads a subscription's promotional offers, win-back offers and offer
/// codes from App Store Connect, each with its prices (one read per offer:
/// where it runs and its US price), and an offer code's custom codes and
/// one-time code batches.
struct SubscriptionOffersReader {
    let transport: any PushTransport

    struct Offers: Hashable, Sendable {
        var promotional: [ExistingPromotionalOffer] = []
        var winBack: [ExistingWinBackOffer] = []
        var codes: [ExistingOfferCode] = []
    }

    @MainActor
    func offers(subscriptionID: String) async throws -> Offers {
        var offers = Offers()
        for resource in try await read(ExistingPromotionalOffer.listPath(subscriptionID: subscriptionID)).data {
            guard var offer = ExistingPromotionalOffer(resource: resource) else { continue }
            offer.prices = try await prices(.promotional, offerID: offer.id)
            offers.promotional.append(offer)
        }
        for resource in try await read(ExistingWinBackOffer.listPath(subscriptionID: subscriptionID)).data {
            guard var offer = ExistingWinBackOffer(resource: resource) else { continue }
            offer.prices = try await prices(.winBack, offerID: offer.id)
            offers.winBack.append(offer)
        }
        for resource in try await read(ExistingOfferCode.listPath(subscriptionID: subscriptionID)).data {
            guard var code = ExistingOfferCode(resource: resource) else { continue }
            code.prices = try await prices(.offerCode, offerID: code.id)
            code.customCodes = try await read(ExistingCustomCode.listPath(offerCodeID: code.id)).data.compactMap(ExistingCustomCode.init)
            code.oneTimeCodes = try await read(ExistingOneTimeCodes.listPath(offerCodeID: code.id)).data.compactMap(ExistingOneTimeCodes.init)
            offers.codes.append(code)
        }
        return offers
    }

    @MainActor
    private func prices(_ resource: SubscriptionOfferResource, offerID: String) async throws -> ExistingOfferPrices {
        let read = try await read(resource.pricesPath(offerID: offerID))
        return ExistingOfferPrices(data: read.data, included: read.included)
    }

    @MainActor
    private func read(_ path: String) async throws -> (data: [[String: Any]], included: [[String: Any]]) {
        try await PushPagedRead.resources(at: path, via: transport) { _ in }
    }
}
