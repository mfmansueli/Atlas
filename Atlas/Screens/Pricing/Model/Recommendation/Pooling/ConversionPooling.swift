//
//  ConversionPooling.swift
//  Atlas
//

import Foundation

/// Conversion per country for apps with little traffic, pooled country →
/// region → world with a Beta-Binomial model and empirical-Bayes priors.
///
/// What it assumes:
/// - Page views are independent trials and each one starts a subscription
///   or not (binomial), at the country's own rate.
/// - The countries of a region (`TerritoryRegion`: Americas, Europe, Asia
///   Pacific, Africa & Middle East) are exchangeable: before seeing their
///   numbers, any two are expected to convert alike, so their rates are
///   draws from one Beta prior per region.
/// - Page views are app-level (App Analytics counts the app's product
///   page, not one product), so a product's conversion is its starts over
///   the app's page views.
/// - Prices differ between the countries pooled together; pooling ignores
///   that, which is why a thin country only counts toward Fairly sure and
///   never toward Sure.
///
/// How it pools:
/// 1. The world prior: the method of moments over every country with page
///    views (`BetaPrior.methodOfMoments`).
/// 2. A region with at least `minimumRegionCountries` countries with page
///    views gets its own prior the same way. A thinner region borrows from
///    the world: its mean is the world prior updated with the region's
///    totals, its strength the world's.
/// 3. A country's rate is its region's prior updated with its own sample:
///    a big country keeps about its own rate, a thin one moves toward the
///    region's. Every strength is at least `minimumStrength` page views.
struct ConversionPooling: Hashable, Sendable {
    /// A prior is worth at least this many page views.
    static let minimumStrength = 100.0
    /// …and at most this many, when countries look alike.
    static let maximumStrength = 20000.0
    /// A region needs this many countries with page views for its own prior.
    static let minimumRegionCountries = 3
    /// Under this own weight, the region carries a country's estimate.
    static let borrowingWeight = 0.5

    /// Each territory's last 90 days, by alpha-3.
    let signals: [String: SalesSignal]
    let world: BetaPrior?
    let regionPriors: [TerritoryRegion: BetaPrior]
    let regionTotals: [TerritoryRegion: SalesSignal]
    /// Alpha-3 → region, for the territories of the catalog.
    let regions: [String: TerritoryRegion]
    /// The product has trial starts somewhere, so HowSure counts trials;
    /// otherwise (no introductory offer, an in-app purchase) it counts starts.
    let usesTrials: Bool

    static let empty = ConversionPooling(signals: [:])

    init(signals: [String: SalesSignal], catalog: TerritoryCatalog = .standard) {
        self.signals = signals
        var regions: [String: TerritoryRegion] = [:]
        for territory in catalog.territories {
            regions[territory.id] = territory.region
        }
        self.regions = regions
        usesTrials = signals.values.contains { $0.trialStarts > 0 }
        let world = BetaPrior.methodOfMoments(
            Array(signals.values), minimumStrength: Self.minimumStrength, maximumStrength: Self.maximumStrength
        )
        self.world = world
        var priors: [TerritoryRegion: BetaPrior] = [:]
        var totals: [TerritoryRegion: SalesSignal] = [:]
        for region in TerritoryRegion.allCases {
            let samples = catalog.territories(in: region).compactMap { signals[$0.id] }.filter { $0.pageViews > 0 }
            let total = samples.reduce(SalesSignal.zero, +)
            totals[region] = total
            if samples.count >= Self.minimumRegionCountries,
               let own = BetaPrior.methodOfMoments(samples, minimumStrength: Self.minimumStrength, maximumStrength: Self.maximumStrength)
            {
                priors[region] = own
            } else if let world {
                priors[region] = BetaPrior(mean: world.posteriorMean(starts: total.starts, pageViews: total.pageViews), strength: world.strength)
            }
        }
        regionPriors = priors
        regionTotals = totals
    }

    /// The country's pooled conversion; nil without page views anywhere or
    /// for a territory outside the catalog.
    func estimate(for territoryID: String) -> PooledConversion? {
        guard let region = regions[territoryID], let prior = regionPriors[region] else { return nil }
        let own = signals[territoryID] ?? .zero
        return PooledConversion(
            territoryID: territoryID,
            region: region,
            own: own,
            regionTotal: regionTotals[region] ?? own,
            prior: prior,
            rate: prior.posteriorMean(starts: own.starts, pageViews: own.pageViews),
            ownWeight: prior.ownWeight(pageViews: own.pageViews)
        )
    }
}
