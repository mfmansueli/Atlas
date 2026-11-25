//
//  PricingPreviewInPicker.swift
//  Atlas
//

import SwiftUI

/// "Preview in"'s one country pop-up, built like the language picker
/// (README-DS §12): the flag, the country's full name and its currency,
/// opening the country menu.
struct PricingPreviewInPicker: View {
    @Bindable var viewModel: PricingViewModel
    let countries: PricingPreviewInCountries
    let territory: Territory

    var body: some View {
        Button {
            viewModel.isPreviewMenuPresented.toggle()
        } label: {
            HStack(spacing: Spacing.xSmall) {
                FlagTile(regionCode: territory.alpha2)
                    .frame(width: 18)
                Text(territory.name)
                    .atlasTextStyle(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(territory.currencyCode)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize()
                Image(systemName: "chevron.down")
                    .atlasTextStyle(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.label2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.small)
            .frame(height: Metrics.menuFieldHeight)
            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(accessibilityText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("pricing.preview.picker")
        .popover(isPresented: $viewModel.isPreviewMenuPresented, arrowEdge: .bottom) {
            PricingPreviewInMenu(countries: countries, currentID: territory.id) { id in
                viewModel.selectPreviewCountry(id)
            }
        }
    }

    /// "Country: Brazil. 12 countries and regions with price changes."
    private var accessibilityText: String {
        let changed = countries.changed.count
        return switch changed {
        case 0: String(localized: "Country: \(territory.name). No price changes.", comment: "kind:accessibility-label")
        case 1: String(localized: "Country: \(territory.name). 1 country or region with price changes.", comment: "kind:accessibility-label")
        default: String(localized: "Country: \(territory.name). \(changed) countries and regions with price changes.", comment: "kind:accessibility-label")
        }
    }
}
