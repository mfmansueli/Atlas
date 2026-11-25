//
//  PricingViewModel+PricesByCountryDebug.swift
//  Atlas
//

#if DEBUG
import Foundation

extension PricingViewModel {
    /// DEBUG-only: Prices by Country's selection, view, Filters, columns,
    /// popover and sheets, once the product's page is open.
    func applyCountriesDebugLaunch(_ launch: PricingDebugLaunch) async {
        guard let productID = productRoute?.productID else { return }
        let state = pricesByCountry
        state.show(productID: productID)
        if !launch.selection.isEmpty { state.selection = Set(launch.selection) }
        if let display = launch.display { state.display = display }
        if let filters = launch.filters { state.filters = filters }
        guard let countries = launch.countries else { return }
        state.mapShowsSuggested = countries.mapShowsSuggested
        for column in countries.shownColumns { state.setShown(column, true) }
        if countries.sortsByRise { state.sortOrder = [KeyPathComparator(\CountryPriceRow.changeSortKey, order: .reverse)] }
        if let territoryID = countries.adjustedTerritory { await acceptStepped(territoryID, productID: productID) }
        // Popovers and sheets wait for the page to be on screen.
        try? await Task.sleep(for: .milliseconds(800))
        state.isFiltersPresented = countries.opensFilters
        state.isAcceptAllPresented = countries.opensAcceptAll
        if let territoryID = countries.popoverTerritory, let row = countryRow(productID: productID, territoryID: territoryID) {
            state.popover = .opening(row)
        }
    }

    /// The country's suggestion one price point up, accepted as the
    /// popover's stepper does.
    private func acceptStepped(_ territoryID: String, productID: String) async {
        await loadCountryPricePoints(productID: productID, territoryID: territoryID)
        guard let row = countryRow(productID: productID, territoryID: territoryID), let suggestion = row.suggested,
              let price = CountryPriceChoice.step(
                  suggestion.customerPrice, by: 1, in: countryPricePoints(productID: productID, territoryID: territoryID)
              )
        else { return }
        await setCountryPrice(.price(price), productID: productID, territoryID: territoryID, source: .suggestion)
    }
}
#endif
