//
//  CountryPricePopover.swift
//  Atlas
//

import SwiftUI

/// Clicking a price or a suggestion (board 73, `pr-prod-why`, `pr-prod-edit`):
/// "Brazil · Lumen Plus Annual", today's price and how it's set, then three
/// choices: the suggested price (a −/+ stepper over the country's price
/// points, why, and what it's based on), Apple's automatic price, or a
/// price you choose from the country's App Store Connect price points. The
/// base country shows only its points. Accept or Set waits in Review & Push.
struct CountryPricePopover: View {
    let viewModel: PricingViewModel
    let productID: PricingProduct.ID
    let row: CountryPriceRow
    @Binding var choice: CountryPriceChoice
    /// The list of points, shorter when the table is.
    var listHeight: CGFloat = Metrics.countriesPointListHeight
    /// In a short window the whole popover scrolls.
    var scrolls = false

    @State private var hasTriedLoading = false

    var body: some View {
        Group {
            if scrolls {
                ScrollView { content }
                    .frame(maxHeight: Metrics.countriesPopoverMaximumHeight)
            } else {
                content
            }
        }
        .frame(width: Metrics.countriesPopoverWidth)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Price in \(row.territory.name)", comment: "kind:label"))
        .accessibilityIdentifier("countries.popover")
        .task(id: row.id) {
            await viewModel.loadCountryPricePoints(productID: productID, territoryID: row.id)
            hasTriedLoading = true
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "\(row.territory.name) · \(productName)")
                    .atlasTextStyle(.headline)
                    .lineLimit(2)
                    .accessibilityIdentifier("countries.popover.title")
                Text("Now \(row.shownPriceText) · \(row.source.title)", comment: "kind:label")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            if row.isBase {
                Text(baseLine)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                pointList
            } else {
                choices
            }
            if let note = row.priceTest {
                // Board 76: a test country's new price ends the test; the
                // comparison's makes the result less sure.
                InlineMessage.warning(note.popoverWarning(countryName: row.territory.name))
                    .accessibilityIdentifier("countries.popover.priceTest")
            }
            Text("Waits in Review & Push. Nothing changes on the App Store until you push.", comment: "kind:label")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            buttons
        }
        .padding(Spacing.large)
        // The table's cells are one line each; the popover's texts wrap.
        .lineLimit(nil)
    }

    private var choices: some View {
        let mode = choice.effectiveMode(for: row)
        return VStack(alignment: .leading, spacing: 0) {
            if row.suggested != nil {
                RadioRow(title: String(localized: "Suggested price", comment: "kind:field-label"), isSelected: mode == .suggested) {
                    select(.suggested, price: row.suggested?.customerPrice)
                }
                .accessibilityIdentifier("countries.popover.suggested")
                if mode == .suggested {
                    CountrySuggestedPriceDetail(
                        row: row,
                        price: choice.price,
                        baseName: viewModel.countriesBaseName(productID: productID),
                        proceeds: proceeds(at: choice.price),
                        isAdjusted: choice.isAdjusted(for: row),
                        onStep: step
                    )
                    .padding(.leading, Spacing.xxLarge)
                    .padding(.bottom, Spacing.small)
                }
            }
            RadioRow(
                title: String(localized: "Apple’s automatic price", comment: "kind:label"),
                detail: automaticDetail,
                isSelected: mode == .automatic
            ) { select(.automatic, price: nil) }
                .accessibilityIdentifier("countries.popover.automatic")
            RadioRow(
                title: String(localized: "A price you choose", comment: "kind:label"),
                detail: String(localized: "Stays until you change it", comment: "kind:label"),
                isSelected: mode == .chosen
            ) { select(.chosen, price: row.shownPrice) }
                .accessibilityIdentifier("countries.popover.chosen")
            if mode == .chosen {
                pointList
                    .padding(.top, Spacing.xSmall)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("How the price is set", comment: "kind:label"))
    }

    private var pointList: some View {
        CountryPricePointList(row: row, points: points, isLoading: isLoading, selection: $choice.price)
            .frame(height: listHeight)
    }

    private var buttons: some View {
        HStack(spacing: Spacing.small) {
            Spacer()
            Button(String(localized: "Cancel", comment: "kind:button")) { viewModel.pricesByCountry.popover = nil }
                .secondaryButton()
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("countries.popover.cancel")
            Button(endsTest ? String(localized: "End Test and Set…", comment: "kind:button") : choice.primaryTitle(for: row)) {
                guard let edit = choice.edit(for: row) else { return }
                if endsTest {
                    let price = switch edit {
                    case .automatic: row.automatic.customerPrice
                    case let .price(value): value
                    }
                    viewModel.askToEndPriceTest(productID: productID, territoryID: row.id, price: price)
                    return
                }
                let source = choice.source(for: row)
                Task { await viewModel.setCountryPrice(edit, productID: productID, territoryID: row.id, source: source) }
            }
            .primaryButton(isDefault: true)
            .disabled(choice.edit(for: row) == nil)
            .accessibilityIdentifier("countries.popover.set")
        }
    }

    /// A new price here ends the country's running price test.
    private var endsTest: Bool {
        row.priceTest?.role == .test
    }

    private func select(_ mode: CountryPriceChoice.Mode, price: Decimal?) {
        choice.mode = mode
        if let price { choice.price = price }
    }

    private func step(_ offset: Int) {
        guard let price = CountryPriceChoice.step(choice.price, by: offset, in: points) else { return }
        choice.price = price
    }

    /// What `price` earns by Apple's own point; nil on estimated points.
    private func proceeds(at price: Decimal) -> Decimal? {
        guard viewModel.hasCountryPricePoints(productID: productID, territoryID: row.id) else { return nil }
        return points.first { !PricingRow.differs($0.customerPrice, price) }?.proceeds
    }

    private var productName: String {
        viewModel.countriesProduct(productID: productID)?.name ?? ""
    }

    private var points: [PricePoint] {
        viewModel.countryPricePoints(productID: productID, territoryID: row.id)
    }

    /// Apple's own points aren't here yet; after a failed read the
    /// estimated ones show (and a price set from them says it needs a refresh).
    private var isLoading: Bool {
        !hasTriedLoading && !viewModel.hasCountryPricePoints(productID: productID, territoryID: row.id)
    }

    /// An in-app purchase's automatic price follows exchange rates and tax;
    /// a subscription's is the base price equalized once (App Store Connect
    /// has no automatic subscription prices).
    private var automaticDetail: String {
        let price = row.currency.format(row.automatic.customerPrice)
        let dollars = CountryPriceRow.dollarsText(row.dollars(row.automatic.customerPrice))
        return row.isInAppPurchase
            ? String(localized: "Follows exchange rates and tax · \(price) today, \(dollars)", comment: "kind:label")
            : String(localized: "The base price, equalized by Apple · \(price), \(dollars)", comment: "kind:label")
    }

    private var baseLine: String {
        row.isInAppPurchase
            ? String(localized: "The base price. Countries on Apple’s automatic price follow it.", comment: "kind:label")
            : String(localized: "The base price. Other countries keep their prices until you change them.", comment: "kind:label")
    }
}
