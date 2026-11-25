//
//  PricingProductFactsStore.swift
//  Atlas
//

import Foundation
import Observation

/// Each product's availability and Family Sharing for its Details tab,
/// read once when the tab shows (and again after Refresh or a push).
@MainActor
@Observable
final class PricingProductFactsStore {
    private(set) var states: [PricingProduct.ID: LoadState<PricingProductFacts>] = [:]
    /// Why a read failed, as the tab shows it.
    private(set) var failures: [PricingProduct.ID: AppleErrorCopy] = [:]
    /// Reads in place of the transport's (DEBUG scenes and tests).
    @ObservationIgnored var reader: (any PricingProductFactsReading)?

    func state(for productID: PricingProduct.ID) -> LoadState<PricingProductFacts> {
        states[productID] ?? .idle
    }

    func failure(for productID: PricingProduct.ID) -> AppleErrorCopy? {
        failures[productID]
    }

    /// Reads `product`'s facts unless they're read or being read; without
    /// a reader or a transport there's nothing to read them with.
    func load(_ product: PricingProduct, transport: () -> (any PushTransport)?) async {
        switch state(for: product.id) {
        case .loading, .loaded: return
        case .idle, .failed: break
        }
        let what = String(localized: "Availability and Family Sharing didn’t load.", comment: "kind:error")
        guard let reader = reader ?? transport().map(PricingProductFactsReader.init) else {
            fail(product.id, copy: AppleErrorCopy(summary: what, details: nil))
            return
        }
        states[product.id] = .loading
        failures[product.id] = nil
        do {
            let facts = try await reader.facts(for: product)
            states[product.id] = .loaded(facts)
        } catch {
            fail(product.id, copy: AppleErrorCopy(what, error: error))
        }
    }

    /// After Refresh or a push: read again when shown.
    func forget() {
        states = [:]
        failures = [:]
    }

    private func fail(_ productID: PricingProduct.ID, copy: AppleErrorCopy) {
        states[productID] = .failed(copy.summary)
        failures[productID] = copy
    }
}
