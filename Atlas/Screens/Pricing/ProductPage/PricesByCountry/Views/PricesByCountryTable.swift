//
//  PricesByCountryTable.swift
//  Atlas
//

import SwiftUI

/// Every country's price for one product (board 73): Country or region,
/// Price and Change always; In US$, Proceeds and How it's set by default;
/// Feels Like, Equalized, Currency, Source and Reason from the Columns
/// menu (`TableColumnCustomization`). Sortable by country, US dollars,
/// feels like and change, and multi-selectable. Narrower than 780 pt, In
/// US$, Proceeds and How it's set fold under the country's name and the
/// Columns menu's own columns hide.
struct PricesByCountryTable: View {
    let viewModel: PricingViewModel
    let productID: PricingProduct.ID
    let rows: [CountryPriceRow]
    let isNarrow: Bool
    /// The popover opens from the table's top instead of the row.
    let opensPopoverAtTop: Bool
    let onAccept: (CountryPriceRow) -> Void

    /// The skeleton's column titles, as the table shows them by default.
    static var columnTitles: [String] {
        PricesByCountryColumn.allCases.filter(\.isShownByDefault).map(\.title)
    }

    var body: some View {
        @Bindable var state = viewModel.pricesByCountry
        Group {
            if isNarrow {
                Table(rows, selection: $state.selection, sortOrder: $state.sortOrder) {
                    countryColumn(isNarrow: true)
                    priceColumn
                    changeColumn
                }
            } else {
                Table(rows, selection: $state.selection, sortOrder: $state.sortOrder, columnCustomization: $state.columns) {
                    countryColumn(isNarrow: false)
                    priceColumn
                    dollarsColumn
                    proceedsColumn
                    sourceColumn
                    feelsLikeColumn
                    Group {
                        equalizedColumn
                        currencyColumn
                        provenanceColumn
                        reasonColumn
                    }
                    changeColumn
                }
            }
        }
        // Rows hold row-sized (24 pt) controls.
        .controlSize(.regular)
        .contextMenu(forSelectionType: Territory.ID.self) { _ in
            EmptyView()
        } primaryAction: { ids in
            guard ids.count == 1, let id = ids.first, let row = rows.first(where: { $0.id == id }) else { return }
            open(row)
        }
        .accessibilityIdentifier("countries.table")
    }

    // MARK: - Columns

    /// A sortable column.
    private typealias Column = TableColumnContent<CountryPriceRow, KeyPathComparator<CountryPriceRow>>
    /// A column that doesn't sort. The table's own builder takes it in; a
    /// `Group` mixing both kinds doesn't, so plain ones group alone.
    private typealias PlainColumn = TableColumnContent<CountryPriceRow, Never>

    private func countryColumn(isNarrow: Bool) -> some Column {
        TableColumn(PricesByCountryColumn.country.title, value: \CountryPriceRow.name) { (row: CountryPriceRow) in
            CountryNameCell(row: row, isNarrow: isNarrow)
        }
        .width(min: 150, ideal: Metrics.countriesNameColumnWidth)
        .customizationID(PricesByCountryColumn.country.customizationID)
        .disabledCustomizationBehavior(.visibility)
    }

    private var priceColumn: some PlainColumn {
        TableColumn(PricesByCountryColumn.price.title) { (row: CountryPriceRow) in priceCell(row) }
            .width(min: Metrics.tablePriceColumnWidth, ideal: 120)
            .customizationID(PricesByCountryColumn.price.customizationID)
            .disabledCustomizationBehavior(.visibility)
    }

    private var dollarsColumn: some Column {
        TableColumn(PricesByCountryColumn.dollars.title, value: \CountryPriceRow.dollarsSortKey) { (row: CountryPriceRow) in
            secondary(row.dollarsText)
                .help(ExchangeRates.current.detailText)
        }
        .width(min: 56, ideal: Metrics.countriesDollarsColumnWidth)
        .alignment(.trailing)
        .customizationID(PricesByCountryColumn.dollars.customizationID)
    }

    private var proceedsColumn: some PlainColumn {
        TableColumn(PricesByCountryColumn.proceeds.title) { (row: CountryPriceRow) in secondary(row.proceedsText) }
            .width(min: 56, ideal: Metrics.countriesDollarsColumnWidth)
            .alignment(.trailing)
            .customizationID(PricesByCountryColumn.proceeds.customizationID)
    }

    private var sourceColumn: some PlainColumn {
        TableColumn(PricesByCountryColumn.source.title) { (row: CountryPriceRow) in CountrySourceCell(row: row) }
            .width(min: 110, ideal: Metrics.countriesSourceColumnWidth)
            .customizationID(PricesByCountryColumn.source.customizationID)
    }

    private var feelsLikeColumn: some Column {
        TableColumn(PricesByCountryColumn.feelsLike.title, value: \CountryPriceRow.feelsLikeSortKey) { (row: CountryPriceRow) in
            CountryFeelsLikeCell(row: row)
        }
        .width(min: 70, ideal: 84)
        .customizationID(PricesByCountryColumn.feelsLike.customizationID)
    }

    private var equalizedColumn: some PlainColumn {
        TableColumn(PricesByCountryColumn.equalized.title) { (row: CountryPriceRow) in
            secondary(row.currency.format(row.automatic.customerPrice))
        }
        .width(min: 70, ideal: 96)
        .alignment(.trailing)
        .customizationID(PricesByCountryColumn.equalized.customizationID)
    }

    private var currencyColumn: some PlainColumn {
        TableColumn(PricesByCountryColumn.currency.title) { (row: CountryPriceRow) in secondary(row.territory.currencyCode) }
            .width(min: 50, ideal: 60)
            .customizationID(PricesByCountryColumn.currency.customizationID)
    }

    private var provenanceColumn: some PlainColumn {
        TableColumn(PricesByCountryColumn.provenance.title) { (row: CountryPriceRow) in CountryProvenanceCell(row: row) }
            .width(min: 90, ideal: 130)
            .customizationID(PricesByCountryColumn.provenance.customizationID)
    }

    private var reasonColumn: some PlainColumn {
        TableColumn(PricesByCountryColumn.reason.title) { (row: CountryPriceRow) in
            secondary(row.reasonText ?? "—")
                .help([row.reasonText, row.howSureTip].compactMap(\.self).joined(separator: "\n"))
        }
        .width(min: 120, ideal: 220)
        .customizationID(PricesByCountryColumn.reason.customizationID)
    }

    private var changeColumn: some Column {
        TableColumn(PricesByCountryColumn.change.title, value: \CountryPriceRow.changeSortKey) { (row: CountryPriceRow) in changeCell(row) }
            .width(min: 150, ideal: Metrics.countriesChangeColumnWidth)
            .customizationID(PricesByCountryColumn.change.customizationID)
            .disabledCustomizationBehavior(.visibility)
    }

    // MARK: - Cells

    private func secondary(_ text: String) -> some View {
        Text(text)
            .atlasTextStyle(.callout)
            .foregroundStyle(Palette.label2)
            .monospacedDigit()
            .lineLimit(1)
    }

    private func priceCell(_ row: CountryPriceRow) -> some View {
        CountryPriceButton(row: row) { open(row) }
            .popover(isPresented: isPresented(row), arrowEdge: .trailing) {
                if let live = viewModel.countryRow(productID: productID, territoryID: row.id) {
                    CountryPricePopover(viewModel: viewModel, productID: productID, row: live, choice: choice(for: live))
                }
            }
    }

    private func changeCell(_ row: CountryPriceRow) -> some View {
        CountryChangeCell(
            row: row,
            isCheckingPrices: viewModel.countriesGrid(productID: productID)?.isChecking == true,
            onOpen: { open(row) },
            onAccept: { onAccept(row) },
            onDismiss: { viewModel.dismissCountrySuggestion(productID: productID, territoryID: row.id) },
            onUndo: { viewModel.undoCountryChange(productID: productID, territoryID: row.id) }
        )
    }

    private func open(_ row: CountryPriceRow) {
        viewModel.pricesByCountry.popover = .opening(row)
    }

    private func isPresented(_ row: CountryPriceRow) -> Binding<Bool> {
        Binding {
            !opensPopoverAtTop && viewModel.pricesByCountry.popover?.territoryID == row.id
        } set: { isPresented in
            if !isPresented, viewModel.pricesByCountry.popover?.territoryID == row.id {
                viewModel.pricesByCountry.popover = nil
            }
        }
    }

    private func choice(for row: CountryPriceRow) -> Binding<CountryPriceChoice> {
        Binding {
            viewModel.pricesByCountry.popover ?? .opening(row)
        } set: { viewModel.pricesByCountry.popover = $0 }
    }
}
