//
//  CountryPriceRowFixtures.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Prices by Country rows made by hand, for the model's tests.
enum CountryPriceRowFixtures {
    static func territory(_ alpha3: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> Territory {
        try #require(TerritoryCatalog.standard.territory(alpha3: alpha3), sourceLocation: sourceLocation)
    }

    static func point(_ price: String) -> PricePoint {
        PricePoint(customerPrice: PricingFixtures.money(price), proceeds: PricingFixtures.money(price) * Decimal(85) / 100)
    }

    static func row(
        _ alpha3: String,
        current: String,
        automatic: String? = nil,
        isBase: Bool = false,
        isInAppPurchase: Bool = false,
        followsApple: Bool = true,
        queued: QueuedCountryPrice? = nil,
        suggestion: String? = nil,
        suggested: String? = nil,
        feelsLike: CountryFeelsLike? = nil,
        provenance: PriceProvenance? = nil
    ) throws -> CountryPriceRow {
        try CountryPriceRow(
            territory: territory(alpha3),
            current: point(current),
            automatic: point(automatic ?? current),
            isBase: isBase,
            isInAppPurchase: isInAppPurchase,
            followsAppleToday: followsApple,
            queued: queued,
            suggestion: suggestion.map(point),
            // The strategy's price: the open suggestion's unless given.
            suggested: (suggested ?? suggestion).map(point),
            feelsLike: feelsLike,
            provenance: provenance
        )
    }

    static func queued(_ price: String, automatic: Bool = false, source: ChangeSource = .you) -> QueuedCountryPrice {
        QueuedCountryPrice(price: PricingFixtures.money(price), isAutomatic: automatic, source: source)
    }

    /// The United States (base), Brazil with a suggestion, Japan on
    /// Apple's price, Germany set by hand, Mexico waiting to go back to
    /// automatic.
    static func sample() throws -> [CountryPriceRow] {
        try [
            row("USA", current: "39.99", isBase: true, followsApple: false),
            row("BRA", current: "249.90", suggestion: "129.90"),
            row("JPN", current: "6800"),
            row("DEU", current: "44.99", automatic: "42.99", followsApple: false),
            row("MEX", current: "999", automatic: "799", followsApple: false, queued: queued("799", automatic: true)),
        ]
    }
}
#endif
