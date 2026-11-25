//
//  PricingViewModel+PreviewIn.swift
//  Atlas
//

import Foundation

// "Preview in", beside the product cards: the In-App Purchases list as the
// App Store shows it in one country, with each product's price there. A
// price that's changing (an open suggestion, or a change waiting in Review
// & Push) shows the new price, the old one struck through and Suggested or
// Not pushed. One country pop-up with Find a country or currency, and ‹ ›
// to the previous or next country with a change.
extension PricingViewModel {
    /// Every country and region the loaded products have a price in, with
    /// those where a price changes marked.
    var previewCountries: PricingPreviewInCountries {
        var territories: [Territory] = []
        for product in catalog?.products ?? [] {
            territories += productMatrices[product.id]?.rows.map(\.territory) ?? []
        }
        let changed = productCards.reduce(into: Set<String>()) { ids, card in
            for (id, price) in card.prices where price.next != nil {
                ids.insert(id)
            }
        }
        return PricingPreviewInCountries(territories: territories, changedIDs: changed)
    }

    /// The chosen country, else the base territory (the United States),
    /// else the first by name; nil until a product's prices are read.
    func previewTerritory(in countries: PricingPreviewInCountries) -> Territory? {
        if let chosen = countries.country(id: previewTerritoryID) { return chosen.territory }
        let base = productMatrices.values.lazy.compactMap { $0.rows.first(where: \.isBase)?.territory }.first
        return base ?? countries.countries.first?.territory
    }

    /// Each product's price in that country, in the catalog's order: a
    /// skeleton while its prices load. Products not sold there, and those
    /// whose prices failed (their card says why), are left out.
    func previewRows(in territoryID: String) -> [PricingPreviewInRow] {
        (catalog?.products ?? []).compactMap { product in
            if let card = card(for: product) {
                return card.prices[territoryID].map { .price(PricingPreviewInPrice.make(product: product, price: $0)) }
            }
            return productErrors[product.id] == nil ? .loading(product.id) : nil
        }
    }

    /// A country from the menu; the menu closes.
    func selectPreviewCountry(_ territoryID: String) {
        previewTerritoryID = territoryID
        isPreviewMenuPresented = false
    }

    /// ›: the next country with a price change.
    func showNextPreviewCountry() {
        let countries = previewCountries
        let current = previewTerritory(in: countries)?.id ?? previewTerritoryID
        if let next = countries.next(after: current) { previewTerritoryID = next.id }
    }

    /// ‹: the previous country with a price change.
    func showPreviousPreviewCountry() {
        let countries = previewCountries
        let current = previewTerritory(in: countries)?.id ?? previewTerritoryID
        if let previous = countries.previous(before: current) { previewTerritoryID = previous.id }
    }
}
