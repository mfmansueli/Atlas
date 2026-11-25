//
//  ExchangeRateSource.swift
//  Atlas
//

import Foundation

/// Where a set of exchange rates comes from.
enum ExchangeRateSource: String, Codable, Hashable, Sendable {
    /// ExchangeRate-API's open access endpoint (open.er-api.com): keyless,
    /// daily, attribution required.
    case exchangeRateAPI
    /// The design prototype's illustrative rates.
    case sample

    /// The attribution the provider asks for: "Rates by ExchangeRate-API".
    var attribution: String {
        switch self {
        case .exchangeRateAPI: String(localized: "Rates by ExchangeRate-API", comment: "kind:hint")
        case .sample: String(localized: "Sample rates", comment: "kind:hint")
        }
    }

    /// The provider's page, linked from the attribution.
    var url: URL? {
        switch self {
        case .exchangeRateAPI: URL(string: "https://www.exchangerate-api.com")
        case .sample: nil
        }
    }
}
