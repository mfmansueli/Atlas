//
//  ExchangeRatesSnapshotTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The bundled `ExchangeRatesSnapshot.json`, ExchangeRate-API's answer and
/// the details line that names the date and source.
@Suite("Exchange rates snapshot")
struct ExchangeRatesSnapshotTests {
    @Test func bundledRatesAreDatedAndCoverEveryTerritoryCurrency() throws {
        let rates = try ExchangeRates.bundled()
        #expect(rates.source == .exchangeRateAPI)
        #expect(rates.date != nil)
        #expect(rates.isValid)
        for territory in TerritoryCatalog.standard.territories {
            #expect(rates.dollars(100, currency: territory.currencyCode) != nil, "\(territory.currencyCode)")
        }
    }

    @Test func decodesTheSnapshotFormat() throws {
        let json = """
        {"source": "exchangeRateAPI", "date": "2026-11-25", "fetched": "2026-11-25T13:47:52Z", "base": "USD", "rates": {"USD": 1, "BRL": 5.894422}}
        """
        let rates = try ExchangeRates(jsonData: Data(json.utf8))
        #expect(rates.date == PricingSampleData.date("2026-11-25"))
        #expect(rates.fetchDate == Date(timeIntervalSince1970: 1_795_614_472))
        #expect(rates.unitsPerDollar["BRL"] == PricingFixtures.money("5.894422"))
        let again = try ExchangeRates(jsonData: rates.jsonData())
        #expect(again == rates)
    }

    @Test func refusesRatesNotInDollarsOrBroken() {
        let euros = #"{"source": "exchangeRateAPI", "date": "2026-11-25", "base": "EUR", "rates": {"EUR": 1}}"#
        #expect(throws: (any Error).self) { try ExchangeRates(jsonData: Data(euros.utf8)) }
        let broken = #"{"source": "exchangeRateAPI", "date": "2026-11-25", "base": "USD", "rates": {"USD": 1, "BRL": -2}}"#
        #expect(throws: (any Error).self) { try ExchangeRates(jsonData: Data(broken.utf8)) }
    }

    @Test func readsExchangeRateAPIsAnswer() throws {
        let json = """
        {"result": "success", "provider": "https://www.exchangerate-api.com", "time_last_update_unix": 1795564951,
         "base_code": "USD", "rates": {"USD": 1, "BRL": 5.894422, "EUR": 0.86}}
        """
        let response = try JSONDecoder().decode(OpenExchangeRateResponse.self, from: Data(json.utf8))
        let fetched = Date(timeIntervalSince1970: 1_795_600_000)
        let rates = try response.exchangeRates(fetchedAt: fetched)
        #expect(rates.source == .exchangeRateAPI)
        #expect(rates.date == Date(timeIntervalSince1970: 1_795_564_951))
        #expect(rates.fetchDate == fetched)
        #expect(rates.unitsPerDollar["EUR"] == PricingFixtures.money("0.86"))
    }

    @Test func refusesAFailedAnswer() throws {
        let json = #"{"result": "error", "time_last_update_unix": 0, "base_code": "USD", "rates": {}}"#
        let response = try JSONDecoder().decode(OpenExchangeRateResponse.self, from: Data(json.utf8))
        #expect(throws: OpenExchangeRateResponse.Problem.failed("error")) { try response.exchangeRates(fetchedAt: .now) }
    }

    @Test func detailsNameTheDateAndTheSource() {
        let rates = ExchangeRates(unitsPerDollar: ["USD": 1], date: PricingSampleData.date("2026-11-25"), source: .exchangeRateAPI)
        #expect(rates.detailText.hasPrefix("Exchange rates of "))
        #expect(rates.detailText.hasSuffix(" · Rates by ExchangeRate-API"))
        #expect(rates.detailText.contains("2026"))
        #expect(ExchangeRates.approximate.detailText == "Sample exchange rates, not live quotes")
        #expect(ExchangeRateSource.exchangeRateAPI.url?.host() == "www.exchangerate-api.com")
    }

    @Test func newerMeansPublishedLater() {
        let older = ExchangeRates(unitsPerDollar: ["USD": 1], date: PricingSampleData.date("2026-11-24"), source: .exchangeRateAPI)
        let newer = ExchangeRates(unitsPerDollar: ["USD": 1], date: PricingSampleData.date("2026-11-25"), source: .exchangeRateAPI)
        #expect(newer.isNewer(than: older))
        #expect(!older.isNewer(than: newer))
        #expect(newer.isNewer(than: .approximate))
    }
}
