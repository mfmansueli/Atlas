//
//  CountryPriceMapView.swift
//  Atlas
//

import SwiftUI

/// Prices by Country as a map of tiles (board 73, `pr-prod-map`): each
/// country the filters keep, coloured by how its price feels for local
/// incomes against the US (`PriceLevel`), Now or Suggested, with a ring
/// where a suggestion waits. Clicking a tile opens its price popover.
struct CountryPriceMapView: View {
    let viewModel: PricingViewModel
    let productID: PricingProduct.ID
    let rows: [CountryPriceRow]

    var body: some View {
        @Bindable var state = viewModel.pricesByCountry
        let tiles = CountryPriceMapTile.tiles(rows, showsSuggested: state.mapShowsSuggested)
        VStack(alignment: .leading, spacing: Spacing.small) {
            // The legend goes under the picker when the page is narrow.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.medium) {
                    pricesPicker
                    Spacer(minLength: Spacing.small)
                    CountryPriceMapLegend()
                }
                VStack(alignment: .leading, spacing: Spacing.small) {
                    pricesPicker
                    CountryPriceMapLegend()
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    ForEach(CountryPriceMapTile.grouped(tiles), id: \.region) { group in
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text(group.region.title)
                                .atlasTextStyle(.subheadline)
                                .foregroundStyle(Palette.label2)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: Metrics.countriesMapTile), spacing: Metrics.countriesMapGap)],
                                      alignment: .leading, spacing: Metrics.countriesMapGap)
                            {
                                ForEach(group.tiles) { tile in
                                    CountryPriceMapTileButton(tile: tile) { open(tile.id) }
                                        .popover(isPresented: isPresented(tile.id), arrowEdge: .trailing) { popover(tile.id) }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, Spacing.small)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Map of prices by country", comment: "kind:accessibility-label"))
        .accessibilityIdentifier("countries.map")
    }

    private func open(_ id: String) {
        guard let row = rows.first(where: { $0.id == id }) else { return }
        viewModel.pricesByCountry.popover = .opening(row)
    }

    @ViewBuilder
    private func popover(_ id: String) -> some View {
        if let row = viewModel.countryRow(productID: productID, territoryID: id) {
            CountryPricePopover(
                viewModel: viewModel,
                productID: productID,
                row: row,
                choice: Binding { viewModel.pricesByCountry.popover ?? .opening(row) } set: { viewModel.pricesByCountry.popover = $0 }
            )
        }
    }

    private func isPresented(_ id: String) -> Binding<Bool> {
        Binding {
            viewModel.pricesByCountry.popover?.territoryID == id
        } set: { isPresented in
            if !isPresented, viewModel.pricesByCountry.popover?.territoryID == id {
                viewModel.pricesByCountry.popover = nil
            }
        }
    }

    private var pricesPicker: some View {
        @Bindable var state = viewModel.pricesByCountry
        return Picker(String(localized: "Prices", comment: "kind:label"), selection: $state.mapShowsSuggested) {
            Text("Now", comment: "kind:segment").tag(false)
            Text("Suggested", comment: "kind:segment").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .disabled(!rows.contains(where: \.hasSuggestion))
        .accessibilityIdentifier("countries.map.prices")
    }
}
