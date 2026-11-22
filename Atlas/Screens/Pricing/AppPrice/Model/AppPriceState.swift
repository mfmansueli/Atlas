//
//  AppPriceState.swift
//  Atlas
//

import Foundation

/// Whether the app has a price yet. A new app has none (App Store
/// Connect's "Set up a starting price… Add Pricing"), so it can't be sold.
enum AppPriceState: Hashable, Sendable {
    case notSet
    case set(AppCurrentPrice)

    var current: AppCurrentPrice? {
        if case let .set(current) = self, current.point != nil { return current }
        return nil
    }
}
