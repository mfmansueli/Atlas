//
//  PriceCalculator.swift
//  Atlas
//

import Foundation

/// The pricing formula (design README, section 10):
///
///     factor = territory price level ÷ base territory's price level
///     target = equalized local price × (1 − intensity + intensity × factor)
///     target = clamp(target, floor, ceiling)   // floor and ceiling are % of base
///     price  = nearest price point with the preferred ending
///              (when the floor applied, the nearest point at or above it)
///
/// Discount only caps the target at the equalized price, the ceiling applies
/// only when premiums are allowed, minimum proceeds raise it, and never raise
/// keeps it at the current price. The steps' text matches the prototype.
struct PriceCalculator: Sendable {
    let catalog: TerritoryCatalog
    let snapshot: PriceIndexSnapshot
    /// Used for minimum proceeds and for prices that aren't on the ladder.
    var commission: Commission
    let resolver: PriceFactorResolver

    init(catalog: TerritoryCatalog = .standard, snapshot: PriceIndexSnapshot, commission: Commission = .smallBusiness) {
        self.catalog = catalog
        self.snapshot = snapshot
        self.commission = commission
        resolver = PriceFactorResolver(snapshot: snapshot, catalog: catalog)
    }

    func calculate(_ input: PriceCalculationInput, strategy: PricingStrategy) -> PriceCalculation {
        let money = CurrencyFormat.forCurrency(input.territory.currencyCode)
        let equalized = input.equalizedPrice
        let basePrice = baseFormat(strategy).format(input.basePrice)
        let header = String(localized: "\(money.format(equalized)) — Apple’s equalized price for \(basePrice)", comment: "kind:description")
        if strategy.method == .equalized {
            let step = String(localized: "Apple equalization: no index applied", comment: "kind:section-title")
            return unchanged(input, header: header, step: step, kind: .equalized, adjustment: .kept)
        }
        if strategy.isExcluded(input.territory.id) {
            let step = String(localized: "Excluded from the index, so it stays equalized", comment: "kind:description")
            return unchanged(input, header: header, step: step, kind: .excluded, adjustment: .excluded)
        }
        let index = indexTarget(input, strategy: strategy)
        let limited = applyLimits(to: index.target, input: input, strategy: strategy)
        let snapped = snap(limited, input: input, strategy: strategy)
        let price = snapped.point.customerPrice
        let multiplier = index.multiplier.trimmed(maxPlaces: 3)
        let summary = String(
            localized: "\(money.format(equalized)) equalized × \(multiplier) = \(money.format(index.target)) → \(limited.adjustment.text) → \(money.format(price))",
            comment: "kind:description"
        )
        return PriceCalculation(
            price: snapped.point,
            equalizedPrice: equalized,
            target: index.target,
            multiplier: index.multiplier,
            factor: index.factor,
            tier: index.tier,
            provenance: index.provenance,
            adjustment: limited.adjustment,
            summary: summary,
            steps: [header, index.step] + limited.steps + [snapped.step],
            raisedToFloor: limited.raisedToFloor
        )
    }

    /// The factor and provenance a strategy gives a territory.
    func resolveFactor(for territory: Territory, strategy: PricingStrategy) -> ResolvedFactor {
        resolver.resolve(territory, strategy: strategy)
    }

    /// How the base price is written: `$39.99`.
    func baseFormat(_ strategy: PricingStrategy) -> CurrencyFormat {
        baseFormat(baseTerritoryID: strategy.baseTerritoryID)
    }

    func baseFormat(baseTerritoryID: String) -> CurrencyFormat {
        CurrencyFormat.forCurrency(catalog.territory(alpha3: baseTerritoryID)?.currencyCode ?? "USD")
    }

    /// A point for a price that isn't on the ladder (an empty ladder), with
    /// proceeds computed from tax and commission.
    func offLadderPoint(_ price: Decimal, territory: Territory) -> PricePoint {
        let decimals = CurrencyFormat.forCurrency(territory.currencyCode).decimals
        let rounded = price.rounded(scale: decimals)
        return PricePoint(
            customerPrice: rounded,
            proceeds: commission.proceeds(customerPrice: rounded, taxRate: territory.taxRate).rounded(scale: 2)
        )
    }

    // MARK: - Index

    /// Equalized × the index (or region) multiplier, before any limit.
    struct IndexTarget {
        var target: Decimal
        var multiplier: Decimal
        var factor: Decimal
        var tier: Int?
        var provenance: PriceProvenance
        var step: String
    }

    private func indexTarget(_ input: PriceCalculationInput, strategy: PricingStrategy) -> IndexTarget {
        let money = CurrencyFormat.forCurrency(input.territory.currencyCode)
        let equalized = input.equalizedPrice
        if strategy.method == .regionalTiers {
            let region = input.territory.region
            let multiplier = strategy.regionMultiplier(for: region)
            let target = equalized * multiplier
            let step = String(localized: "× \(multiplier.fixed(2)) (\(region.title) tier) = \(money.format(target))", comment: "kind:description")
            let provenance = PriceProvenance(kind: .regionalTier(region), isFallback: false)
            return IndexTarget(target: target, multiplier: multiplier, factor: multiplier, tier: nil, provenance: provenance, step: step)
        }
        let resolved = resolver.resolve(input.territory, strategy: strategy)
        var factor = resolved.factor
        var tier: Int?
        if strategy.tiersEnabled {
            let index = strategy.tiers.tierIndex(for: factor)
            tier = index + 1
            factor = strategy.tiers.share(forTier: index)
        }
        let intensity = min(max(strategy.intensity, 0), 1)
        let multiplier = 1 - intensity + intensity * factor
        let target = equalized * multiplier
        let label = tier.map { String(localized: "\(resolved.provenance.label), tier \($0)", comment: "kind:other") } ?? resolved.provenance.label
        let step = intensity == 1
            ? "× " + factor.fixed(2) + " (" + label + ") = " + money.format(target)
            : "× (1 − " + intensity.fixed(2) + " + " + intensity.fixed(2) + " × " + factor.fixed(2) + ") = × "
            + multiplier.fixed(3) + " (" + label + ") = " + money.format(target)
        return IndexTarget(target: target, multiplier: multiplier, factor: factor, tier: tier, provenance: resolved.provenance, step: step)
    }

    private func unchanged(
        _ input: PriceCalculationInput,
        header: String,
        step: String,
        kind: PriceProvenance.Kind,
        adjustment: PriceAdjustment
    ) -> PriceCalculation {
        let money = CurrencyFormat.forCurrency(input.territory.currencyCode)
        let equalized = input.equalizedPrice
        let point = input.ladder.point(at: equalized) ?? offLadderPoint(equalized, territory: input.territory)
        let price = money.format(equalized)
        let summary = adjustment == .kept
            ? String(localized: "\(price) equalized → kept", comment: "kind:description")
            : String(localized: "\(price) equalized → excluded → \(price)", comment: "kind:description")
        return PriceCalculation(
            price: point,
            equalizedPrice: equalized,
            target: equalized,
            multiplier: 1,
            factor: 1,
            tier: nil,
            provenance: PriceProvenance(kind: kind, isFallback: false),
            adjustment: adjustment,
            summary: summary,
            steps: [header, step]
        )
    }
}
