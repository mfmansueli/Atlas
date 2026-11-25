//
//  OpenExchangeRateFetcher.swift
//  Atlas
//

import Foundation

/// Fetches ExchangeRate-API's open access rates. Keyless; sends nothing
/// about the person or their apps.
struct OpenExchangeRateFetcher: ExchangeRateFetching {
    static let url = URL(string: "https://open.er-api.com/v6/latest/USD")

    var session: URLSession = .shared

    func latest() async throws -> ExchangeRates {
        guard let url = Self.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(OpenExchangeRateResponse.self, from: data).exchangeRates(fetchedAt: .now)
    }
}
