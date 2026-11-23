//
//  OfferTerritoryPricesEditor.swift
//  Atlas
//

import SwiftUI

/// Countries or regions priced apart from the equalized price: each with
/// its price in its own currency (a price point Apple has there), added
/// from a menu and removed with its minus button.
struct OfferTerritoryPricesEditor: View {
    /// Territory (alpha-3) → the price typed.
    @Binding var prices: [String: String]
    let identifier: String

    private var territories: [Territory] {
        TerritoryCatalog.standard.territories
            .filter { $0.id != NewSubscription.baseTerritoryID && prices[$0.id] == nil }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        ForEach(prices.keys.sorted(), id: \.self) { territoryID in
            let territory = TerritoryCatalog.standard.territory(alpha3: territoryID)
            LabeledContent {
                HStack(spacing: Spacing.xSmall) {
                    TextField("Price", text: Binding { prices[territoryID] ?? "" } set: { prices[territoryID] = $0 })
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                        .accessibilityIdentifier("\(identifier).territoryPrice.\(territoryID)")
                    Text(verbatim: territory?.currencyCode ?? "")
                        .foregroundStyle(Palette.label2)
                        .frame(width: 36, alignment: .leading)
                    Button {
                        prices[territoryID] = nil
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "Use the equalized price"))
                    .accessibilityLabel(String(localized: "Use the equalized price in \(territory?.name ?? territoryID)"))
                }
            } label: {
                HStack(spacing: Spacing.small) {
                    FlagTile(regionCode: territory?.alpha2 ?? "")
                    Text(territory?.name ?? territoryID)
                }
            }
        }
        Menu("Set a Price Apart…") {
            ForEach(territories) { territory in
                Button(territory.name) { prices[territory.id] = "" }
            }
        }
        .fixedSize()
        .accessibilityIdentifier("\(identifier).addTerritoryPrice")
    }
}
