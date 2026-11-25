//
//  CountryFeelsLikeTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("Prices by Country: feels like")
struct CountryFeelsLikeTests {
    /// Brazil-like: R$ 5.4 per US dollar with tax, a purchasing-power
    /// factor of 0.56, against a $39.99 base.
    private let feels = CountryFeelsLike(
        multiplier: Decimal(string: "5.4") ?? 0, factor: Decimal(string: "0.56") ?? 0, basePrice: Decimal(string: "39.99") ?? 0, baseCurrency: "USD"
    )

    @Test func thePriceForLocalIncomesInTheBaseCurrency() throws {
        let value = try #require(feels.value(PricingFixtures.money("249.90")))
        #expect(abs(value.doubleValue - 82.64) < 0.01)
        #expect(feels.valueText(PricingFixtures.money("249.90")) == "$83")
        #expect(feels.ratioText(PricingFixtures.money("249.90")) == "2.1×")
    }

    @Test func theRatioPicksThePriceLevel() {
        #expect(feels.level(PricingFixtures.money("249.90")) == .muchPricier)
        #expect(feels.level(PricingFixtures.money("120.93")) == .aboutTheSame)
        #expect(feels.level(PricingFixtures.money("60")) == .muchCheaper)
    }

    @Test func withoutAFactorNothingFeelsLikeAnything() {
        let none = CountryFeelsLike(multiplier: 0, factor: 1, basePrice: 10, baseCurrency: "USD")
        #expect(none.value(10) == nil)
        #expect(none.ratio(10) == nil)
        #expect(none.valueText(10) == "—")
        #expect(none.ratioText(10) == "—")
    }
}
#endif
