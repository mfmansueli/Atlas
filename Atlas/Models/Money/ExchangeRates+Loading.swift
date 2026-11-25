//
//  ExchangeRates+Loading.swift
//  Atlas
//

import Foundation

extension ExchangeRates {
    /// `ExchangeRatesSnapshot.json` in `Screens/Pricing/Resources`.
    static let resourceName = "ExchangeRatesSnapshot"

    enum LoadingError: Error, Equatable {
        case missingResource
    }

    /// The rates bundled with this release.
    static func bundled(in bundle: Bundle = .main) throws -> ExchangeRates {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw LoadingError.missingResource
        }
        return try ExchangeRates(jsonData: Data(contentsOf: url))
    }

    init(jsonData: Data) throws {
        self = try JSONDecoder().decode(ExchangeRatesFile.self, from: jsonData).exchangeRates()
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(ExchangeRatesFile(self))
    }
}
