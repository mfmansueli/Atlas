//
//  PricesByCountryState.swift
//  Atlas
//

import Observation
import SwiftUI

/// What Prices by Country keeps while the person works in it: the find
/// field, the Filters, the sort order, the columns, Table · Map ·
/// Histogram, the selected countries and the open price popover. Find,
/// sort, selection and the popover are one product's; the Filters,
/// columns and view stay as the person moves between products.
@MainActor
@Observable
final class PricesByCountryState {
    private(set) var productID: String?
    var search = ""
    var filters = PricesByCountryFilters()
    var sortOrder: [KeyPathComparator<CountryPriceRow>] = []
    var selection: Set<Territory.ID> = []
    /// The price popover's country and choice; nil when closed.
    var popover: CountryPriceChoice?
    var columns = PricesByCountryState.defaultColumns
    var display = PricingDisplay.table
    /// The map colours suggested prices instead of today's.
    var mapShowsSuggested = false
    /// Accept All N… is open.
    var isAcceptAllPresented = false
    /// The Filters popover is open.
    var isFiltersPresented = false
    /// The page is at its smallest (860 × 560): the inspector floats over
    /// the table instead of sitting beside it.
    var isCompact = false

    /// Starts afresh for another product.
    func show(productID: String) {
        guard productID != self.productID else { return }
        self.productID = productID
        search = ""
        sortOrder = []
        selection = []
        popover = nil
        isAcceptAllPresented = false
    }

    /// Clear Filters.
    func clearFilters() {
        filters = PricesByCountryFilters()
    }

    // MARK: - Columns

    func isShown(_ column: PricesByCountryColumn) -> Bool {
        column.isAlwaysShown || columns[visibility: column.customizationID] != .hidden
    }

    func setShown(_ column: PricesByCountryColumn, _ isShown: Bool) {
        guard !column.isAlwaysShown else { return }
        columns[visibility: column.customizationID] = isShown ? .visible : .hidden
    }

    /// In US$, Proceeds and How it's set show; the Columns menu's own don't.
    static var defaultColumns: TableColumnCustomization<CountryPriceRow> {
        var columns = TableColumnCustomization<CountryPriceRow>()
        for column in PricesByCountryColumn.allCases {
            columns[visibility: column.customizationID] = column.isShownByDefault ? .visible : .hidden
        }
        return columns
    }
}
