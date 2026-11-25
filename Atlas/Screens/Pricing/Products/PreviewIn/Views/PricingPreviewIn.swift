//
//  PricingPreviewIn.swift
//  Atlas
//

import SwiftUI

/// Beside the products (under them when the window is narrow): the
/// In-App Purchases list as the App Store shows it in one country. One
/// country pop-up with Find a country or currency, ‹ › to the previous or
/// next country with a price change, and each product's price there; a
/// changing price shows the old one struck through with Suggested or Not
/// pushed, and about what it is in US dollars. Clicking a product opens its
/// page on that country.
struct PricingPreviewIn: View {
    @Bindable var viewModel: PricingViewModel
    /// Opens a product's page on a country: the product, and the country's
    /// alpha-3 code.
    let onOpenProduct: (PricingProduct.ID, String) -> Void

    /// The column's width beside the cards.
    static let width: CGFloat = 256

    var body: some View {
        let countries = viewModel.previewCountries
        let territory = viewModel.previewTerritory(in: countries)
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(String(localized: "Preview in", comment: "kind:section-title"))
                .atlasTextStyle(.headline)
                .accessibilityAddTraits(.isHeader)
            if let territory {
                HStack(spacing: Spacing.xSmall) {
                    PricingPreviewInPicker(viewModel: viewModel, countries: countries, territory: territory)
                    arrows(countries, current: territory.id)
                }
                list(in: territory)
                Text("What people in \(territory.name) see, with tax. Click a product to change its price there.", comment: "kind:description")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xxSmall)
            } else {
                loading
            }
        }
        .frame(width: Self.width)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.preview")
    }

    // MARK: - The list

    private func list(in territory: Territory) -> some View {
        let rows = viewModel.previewRows(in: territory.id)
        return VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("App Store · \(territory.name)", comment: "kind:label")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
            Text("In-App Purchases", comment: "kind:section-title")
                .atlasTextStyle(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(rows) { row in
                switch row {
                case let .price(price):
                    PricingPreviewInProductRow(price: price, countryName: territory.name) {
                        onOpenProduct(price.id, territory.id)
                    }
                case .loading:
                    PricingPreviewInSkeletonRow()
                }
            }
            if rows.isEmpty {
                Text("None of your products are sold in \(territory.name).", comment: "kind:empty-state")
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pricing.preview.none")
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.preview.list")
    }

    /// Before any product's prices are read: the picker and the list in
    /// grey.
    private var loading: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            SkeletonBlock(height: Metrics.menuFieldHeight, cornerRadius: Radius.field)
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                SkeletonBlock(width: 96, height: 8)
                SkeletonBlock(width: 120)
                ForEach(0..<3, id: \.self) { _ in
                    PricingPreviewInSkeletonRow()
                }
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Preview in, prices loading", comment: "kind:accessibility-label"))
        .accessibilityIdentifier("pricing.preview.loading")
    }

    // MARK: - ‹ ›

    private func arrows(_ countries: PricingPreviewInCountries, current: String) -> some View {
        let previous = countries.previous(before: current)
        let next = countries.next(after: current)
        return ControlGroup {
            Button(action: viewModel.showPreviousPreviewCountry) {
                Image(systemName: "chevron.left")
            }
            .disabled(previous == nil || previous?.id == current)
            .keyboardShortcut("[", modifiers: .command)
            .help(arrowHelp(previous, String(localized: "Previous country with a change", comment: "kind:tooltip"), shortcut: "⌘["))
            .accessibilityLabel(Text(arrowHelp(previous, String(localized: "Previous country with a change", comment: "kind:tooltip"))))
            .accessibilityIdentifier("pricing.preview.previous")
            Button(action: viewModel.showNextPreviewCountry) {
                Image(systemName: "chevron.right")
            }
            .disabled(next == nil || next?.id == current)
            .keyboardShortcut("]", modifiers: .command)
            .help(arrowHelp(next, String(localized: "Next country with a change", comment: "kind:tooltip"), shortcut: "⌘]"))
            .accessibilityLabel(Text(arrowHelp(next, String(localized: "Next country with a change", comment: "kind:tooltip"))))
            .accessibilityIdentifier("pricing.preview.next")
        }
        .fixedSize()
    }

    /// "Next country with a change: Japan  ⌘]"; VoiceOver reads it without
    /// the shortcut.
    private func arrowHelp(_ country: PricingPreviewInCountry?, _ title: String, shortcut: String? = nil) -> String {
        let help = country.map { "\(title): \($0.territory.name)" } ?? title
        return shortcut.map { "\(help)  \($0)" } ?? help
    }
}
