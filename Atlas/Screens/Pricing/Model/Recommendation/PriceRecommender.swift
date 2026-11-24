//
//  PriceRecommender.swift
//  Atlas
//

import Foundation

/// The suggestion behind "Show suggestions" (design README, section 11).
///
/// - Purchasing power, always: the Recommended strategy (World Bank PPP at
///   full intensity, floor 30%, discount only). "Feels like" = local price ÷
///   equalization multiplier ÷ factor, in base-currency terms.
/// - The app's sales, when the key can read them: with ≥ 1,000 page views and
///   ≥ 15 starts confidence is Medium; a price that feels high but converts
///   at ≥ 75% of the base territory's gets half the step; under 60% the
///   reason says "many page views, few starts".
/// - An earlier change in the territory: confidence is High, and a cut that
///   didn't lift starts holds the current price.
struct PriceRecommender: Sendable {
    /// The basis line when the key's role can't read sales.
    static let cantReadSalesLine = String(localized: "Sales: this key’s role can’t read Sales and Trends", comment: "kind:description")
    static let minimumPageViews = 1000
    static let minimumStarts = 15
    /// Feels this many times the base price or more: likely holds people back.
    static let holdsBackRatio = Decimal(125) / 100
    /// Converts at least this share of the base territory: smaller step.
    static let softStepConversionShare = 0.75
    /// Converts under this share of the base territory: few starts.
    static let weakConversionShare = 0.6
    static let softStepIntensity = Decimal(1) / 2

    let calculator: PriceCalculator
    var baseTerritoryID = "USA"

    init(calculator: PriceCalculator, baseTerritoryID: String = "USA") {
        self.calculator = calculator
        self.baseTerritoryID = baseTerritoryID
    }

    /// local price ÷ equalization multiplier ÷ factor.
    static func feelsLike(_ price: Decimal, equalizationMultiplier: Decimal, factor: Decimal) -> Decimal {
        guard equalizationMultiplier > 0, factor > 0 else { return price }
        return price / equalizationMultiplier / factor
    }

    func recommend(_ input: PriceCalculationInput, evidence: SalesEvidence) -> Recommendation {
        let current = input.currentPrice ?? input.equalizedPrice
        var strategy = PricingStrategy.recommended(baseTerritoryID: baseTerritoryID)
        let resolved = calculator.resolveFactor(for: input.territory, strategy: strategy)
        let feels = Self.feelsLike(current, equalizationMultiplier: input.equalizationMultiplier, factor: resolved.factor)
        let ratio = input.basePrice > 0 ? feels / input.basePrice : 1
        if input.territory.id == baseTerritoryID {
            return baseRecommendation(input, current: current, feels: feels, factor: resolved.factor)
        }
        let facts = Facts(evidence: evidence, ratio: ratio)
        strategy.intensity = facts.isSoftStep ? Self.softStepIntensity : 1
        var currentInput = input
        currentInput.currentPrice = current
        let calculation = calculator.calculate(currentInput, strategy: strategy)
        let price = facts.isHolding
            ? input.ladder.point(at: current) ?? calculator.offLadderPoint(current, territory: input.territory)
            : calculation.price
        let isUnchanged = (price.customerPrice - current).magnitude < Decimal(1) / 1000
        let feelsSuggested = Self.feelsLike(price.customerPrice, equalizationMultiplier: input.equalizationMultiplier, factor: resolved.factor)
        let base = calculator.baseFormat(baseTerritoryID: baseTerritoryID)
        return Recommendation(
            price: price,
            currentPrice: current,
            isUnchanged: isUnchanged,
            isBaseTerritory: false,
            confidence: facts.confidence,
            reason: reason(facts, ratio: ratio, isUnchanged: isUnchanged, calculation: calculation),
            basis: basis(facts, input: input, current: current, resolved: resolved),
            feelsLike: feels,
            feelsLikeSuggested: feelsSuggested,
            ratio: ratio,
            suggestedRatio: input.basePrice > 0 ? feelsSuggested / input.basePrice : 1,
            factor: resolved.factor,
            feelsLikeText: base.formatWhole(feels),
            feelsLikeSuggestedText: base.formatWhole(feelsSuggested),
            isHolding: facts.isHolding,
            isSoftStep: facts.isSoftStep,
            summary: facts.isHolding
                ? String(localized: "Holding at \(CurrencyFormat.format(current, currency: input.territory.currencyCode))", comment: "kind:description")
                : calculation.summary,
            steps: calculation.steps,
            calculation: calculation
        )
    }

    // MARK: - Private

    /// What the sales evidence says, read once.
    private struct Facts {
        var signal: SalesSignal?
        var prior: PriorPriceChange?
        var canReadSales: Bool
        var hasEnoughSales: Bool
        var conversion: Double?
        var reference: Double?
        var isSoftStep: Bool
        var isHolding: Bool

        init(evidence: SalesEvidence, ratio: Decimal) {
            canReadSales = evidence.canReadSales
            signal = canReadSales ? evidence.signal : nil
            prior = canReadSales ? evidence.priorChange : nil
            hasEnoughSales = signal.map { $0.pageViews >= PriceRecommender.minimumPageViews && $0.starts >= PriceRecommender.minimumStarts } ?? false
            conversion = signal?.conversion
            reference = canReadSales ? evidence.baseSignal?.conversion : nil
            if hasEnoughSales, let conversion, let reference {
                isSoftStep = conversion >= PriceRecommender.softStepConversionShare * reference && ratio >= PriceRecommender.holdsBackRatio
            } else {
                isSoftStep = false
            }
            isHolding = prior.map { !$0.liftedStarts } ?? false
        }

        var confidence: RecommendationConfidence {
            prior != nil ? .high : hasEnoughSales ? .medium : .low
        }

        var hasFewStarts: Bool {
            guard hasEnoughSales, let conversion, let reference else { return false }
            return conversion < PriceRecommender.weakConversionShare * reference
        }
    }

    private var baseReference: String {
        calculator.catalog.territory(alpha3: baseTerritoryID)?.referenceName ?? baseTerritoryID
    }

    private func reason(_ facts: Facts, ratio: Decimal, isUnchanged: Bool, calculation: PriceCalculation) -> String {
        let feels = String(localized: "Feels like \(PricingText.ratio(ratio)) the \(baseReference) price", comment: "kind:section-title")
        if facts.isHolding { return String(localized: "Last cut didn’t lift starts · holding", comment: "kind:description") }
        if isUnchanged {
            return ratio < Decimal(95) / 100
                ? String(localized: "Already below the local price level", comment: "kind:description")
                : String(localized: "Already matches local purchasing power", comment: "kind:section-title")
        }
        guard ratio >= Self.holdsBackRatio else { return feels }
        var parts = [feels]
        if facts.hasFewStarts {
            parts.append(String(localized: "many page views, few starts", comment: "kind:description"))
        } else if facts.isSoftStep {
            parts.append(String(localized: "converts well, smaller step", comment: "kind:other"))
        }
        if facts.prior != nil { parts.append(String(localized: "last cut lifted starts", comment: "kind:other")) }
        if calculation.raisedToFloor { parts.append(String(localized: "held at the floor", comment: "kind:other")) }
        return parts.joined(separator: " · ")
    }

    private func basis(_ facts: Facts, input: PriceCalculationInput, current: Decimal, resolved: ResolvedFactor) -> [String] {
        let edition = calculator.snapshot.index(.worldBank)?.edition.provenanceLabel ?? PriceIndexSource.worldBank.shortName
        let level = resolved.factor.fixed(2)
        var power = String(localized: "Purchasing power: \(edition) price level \(level)", comment: "kind:other")
        switch resolved.provenance.kind {
        case .regionMedian: power = String(localized: "\(power) (region median, no World Bank data)", comment: "kind:description")
        case .equalized: power = String(localized: "\(power) (no World Bank data)", comment: "kind:other")
        default: break
        }
        var lines = [power]
        if !facts.canReadSales {
            lines.append(Self.cantReadSalesLine)
        } else if let signal = facts.signal {
            let pageViews = PricingText.grouped(signal.pageViews)
            let conversion = PricingText.percent(facts.conversion ?? 0)
            var sales = String(localized: "Your sales, last 28 days: \(pageViews) page views · \(signal.starts) starts · \(conversion)", comment: "kind:other")
            if let reference = facts.reference {
                sales = String(localized: "\(sales) (\(baseReference) \(PricingText.percent(reference)))", comment: "kind:other")
            }
            lines.append(facts.hasEnoughSales ? sales : String(localized: "\(sales), too few to count", comment: "kind:other"))
        } else {
            lines.append(String(localized: "Your sales: too few in this territory to count", comment: "kind:description"))
        }
        if let prior = facts.prior {
            let money = CurrencyFormat.forCurrency(input.territory.currencyCode)
            let date = PricingText.date(prior.date)
            let before = money.format(prior.previousPrice)
            let after = money.format(current)
            lines.append(String(
                localized: "Earlier change, \(date): \(before) → \(after), starts \(prior.before.starts) → \(prior.after.starts) in 28 days",
                comment: "kind:other"
            ))
        }
        return lines
    }

    private func baseRecommendation(_ input: PriceCalculationInput, current: Decimal, feels: Decimal, factor _: Decimal) -> Recommendation {
        let base = calculator.baseFormat(baseTerritoryID: baseTerritoryID)
        let price = input.ladder.point(at: current) ?? calculator.offLadderPoint(current, territory: input.territory)
        return Recommendation(
            price: price,
            currentPrice: current,
            isUnchanged: true,
            isBaseTerritory: true,
            confidence: nil,
            reason: String(localized: "Base territory", comment: "kind:section-title"),
            basis: [String(localized: "The base price every other territory is derived from.", comment: "kind:description")],
            feelsLike: feels,
            feelsLikeSuggested: feels,
            ratio: 1,
            suggestedRatio: 1,
            factor: 1,
            feelsLikeText: base.formatWhole(feels),
            feelsLikeSuggestedText: base.formatWhole(feels),
            isHolding: false,
            isSoftStep: false,
            summary: String(localized: "Base territory", comment: "kind:description"),
            steps: [String(localized: "\(base.format(current)) — base price", comment: "kind:other")],
            calculation: nil
        )
    }
}
