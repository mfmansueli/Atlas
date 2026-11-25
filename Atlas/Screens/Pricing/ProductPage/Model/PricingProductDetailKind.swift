//
//  PricingProductDetailKind.swift
//  Atlas
//

import Foundation

/// Which fact a Details row of a product's page shows (`PricingProductDetails`).
enum PricingProductDetailKind: String, Sendable {
    case type
    case productID
    case group
    case basePrice
    case availability
    case familySharing
    case commission
    case exchangeRates
    case taxCategory
}
