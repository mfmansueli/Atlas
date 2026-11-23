//
//  InAppPurchaseOfferCodesReader.swift
//  Atlas
//

import Foundation

/// Reads an in-app purchase's offer codes from App Store Connect, each with
/// its prices (one read per offer code: where it runs and its US price),
/// custom codes and batches of one-time codes. Prices are read apart from
/// the list because the list's `include` takes at most 50 of them.
struct InAppPurchaseOfferCodesReader {
    let transport: any PushTransport

    @MainActor
    func offerCodes(purchaseID: String) async throws -> [ExistingInAppPurchaseOfferCode] {
        var codes: [ExistingInAppPurchaseOfferCode] = []
        for resource in try await read(InAppPurchaseOfferCodeResource.listPath(purchaseID: purchaseID)).data {
            guard var code = ExistingInAppPurchaseOfferCode(resource: resource) else { continue }
            let prices = try await read(InAppPurchaseOfferCodeResource.pricesPath(offerCodeID: code.id))
            code.prices = ExistingOfferPrices(
                data: prices.data, included: prices.included,
                pricePointRelationship: OfferPriceOwner.inAppPurchase(purchaseID).pricePointRelationship
            )
            code.customCodes = try await read(InAppPurchaseOfferCodeResource.customCodesListPath(offerCodeID: code.id)).data
                .compactMap(ExistingCustomCode.init)
            code.oneTimeCodes = try await read(InAppPurchaseOfferCodeResource.oneTimeCodesListPath(offerCodeID: code.id)).data
                .compactMap(ExistingOneTimeCodes.init)
            codes.append(code)
        }
        return codes
    }

    @MainActor
    private func read(_ path: String) async throws -> (data: [[String: Any]], included: [[String: Any]]) {
        try await PushPagedRead.resources(at: path, via: transport) { _ in }
    }
}
