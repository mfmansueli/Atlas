//
//  PricingViewModel+ProductPageDebug.swift
//  Atlas
//

#if DEBUG
import Foundation

extension PricingViewModel {
    /// DEBUG-only: opens a product's page (`pr-prod*`) the way a click on
    /// its card, or Show Countries, does, then the tab the scene shows.
    func applyProductPageDebugLaunch(_ route: PricingProductRoute?) async {
        guard let route else { return }
        if route.filter == .suggested {
            showSuggestedCountries(productID: route.productID)
        } else {
            openProduct(route.productID, territory: route.focusedTerritory, filter: route.filter)
        }
        productRoute?.tab = route.tab
        await select(productID: route.productID)
        // `pr-prod-sel-chat`: the focused country stays selected, with its bar.
        if let territory = route.focusedTerritory {
            pricesByCountry.show(productID: route.productID)
            pricesByCountry.selection = [territory]
        }
    }
}
#endif
