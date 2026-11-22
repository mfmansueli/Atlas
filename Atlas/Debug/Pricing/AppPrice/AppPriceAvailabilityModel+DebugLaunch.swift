//
//  AppPriceAvailabilityModel+DebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

extension AppPriceAvailabilityModel {
    /// Opens the sheet a DEBUG scene asks for, as the card's button would.
    /// Does nothing outside DEBUG scenes.
    func applyDebugLaunch(from services: any AppPriceAvailabilityServices) {
        guard let debug = services as? DebugAppPriceAvailabilityServices else { return }
        switch debug.opens {
        case .price: isPriceSheetPresented = true
        case .availability: isAvailabilitySheetPresented = true
        case nil: break
        }
    }
}
#endif
