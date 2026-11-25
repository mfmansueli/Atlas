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
/// - The app's sales, when they count (90 days): conversion is pooled
///   country → region → world (`ConversionPooling`), so a thin country
///   borrows its region's. With enough evidence (`PriceConfidenceRule`'s
///   300 page views and 10 trials, in the country or its region), a price
///   that feels high but converts at ≥ 75% of the base territory's moves
///   less: the purchasing-power target is the prior, and the step shrinks
///   toward half only as far as the country's own share of the pooled
///   estimate goes (`PooledConversion.ownWeight`). Under 60% the reason
///   says "many page views, few starts".
/// - An earlier change in the territory: a cut that didn't lift starts
///   holds the current price.
/// - How sure comes from `PriceConfidenceRule` (index trust, real grid,
///   sales, earlier change), with its one-line reason.
/// - A step under 5% of today's price (`minimumChange`) keeps today's
///   price: it's a price-grid rounding, not a purchasing-power gap.
/// - A price that already feels within 15% of the target (`matchBand`)
///   keeps today's: purchasing-power data isn't that precise. A step that
///   would leave the price feeling further from the target than today's
///   keeps today's too: at the bottom of the grid one point is 25–50%
///   (Paraguay US$ 1.99 → 1.49 felt 1.15× and would feel 0.86×).
/// - A price at most 5% under the floor (`floorTolerance`) is already at
///   the floor (Bhutan US$ 1.49 against a US$ 1.50 floor), not raised a
///   whole point to US$ 1.99. Alba, 25 Nov 2026: 101 suggestions → 47.
struct PriceRecommender: Sendable {
    /// The basis line when the key's role can't read sales.
    static let cantReadSalesLine = String(localized: "Sales: this key’s role can’t read Sales and Trends", comment: "kind:description")
    /// Feels this many times the base price or more: likely holds people back.
    static let holdsBackRatio = Decimal(125) / 100
    /// Converts at least this share of the base territory: smaller step.
    static let softStepConversionShare = 0.75
    /// Converts under this share of the base territory: few starts.
    static let weakConversionShare = 0.6
    static let softStepIntensity = Decimal(1) / 2
    /// A suggestion closer than this to today's price keeps today's: the
    /// index and the price grid can't tell such a step from noise (COP
    /// 10.000 → 9.999, ₸1,150 → ₸1,149). The floor still applies.
    static let minimumChange = Decimal(5) / 100
    /// Feels within this share of the target (either side): already matches.
    static let matchBand = Decimal(15) / 100
    /// Under the floor by at most this share: already at the floor.
    static let floorTolerance = Decimal(5) / 100

    let calculator: PriceCalculator
    var baseTerritoryID = "USA"
    /// The day an index edition's age is judged on, and the 28 days after
    /// an earlier change when the sales don't say how far they go.
    var asOf: Date

    init(calculator: PriceCalculator, baseTerritoryID: String = "USA", asOf: Date = .now) {
        self.calculator = calculator
        self.baseTerritoryID = baseTerritoryID
        self.asOf = asOf
    }

    /// Whether moving from today's price to `suggested` is at least
    /// `minimumChange` of today's price.
    static func isMeaningfulChange(from current: Decimal, to suggested: Decimal) -> Bool {
        guard current > 0 else { return suggested != current }
        return (suggested - current).magnitude / current >= minimumChange
    }

    /// Whether today's price already feels within `matchBand` of the
    /// target (a ratio of 1).
    static func matchesTarget(ratio: Decimal) -> Bool {
        (ratio - 1).magnitude <= matchBand
    }

    /// Whether a step from feeling `current` × the base to `candidate` ×
    /// lands closer to 1, judged on a log scale so 2× and 0.5× are as far.
    static func movesCloser(from current: Decimal, to candidate: Decimal) -> Bool {
        guard current > 0, candidate > 0 else { return true }
        return abs(log(candidate.doubleValue)) < abs(log(current.doubleValue))
    }

    /// Whether today's price is at the floor already, allowing for the grid:
    /// at most `floorTolerance` under it.
    static func isAtFloor(_ current: Decimal, floor: Decimal) -> Bool {
        current >= floor * (1 - floorTolerance)
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
        strategy.intensity = facts.isSoftStep ? facts.softIntensity : 1
        var currentInput = input
        currentInput.currentPrice = current
        let calculation = calculator.calculate(currentInput, strategy: strategy)
        let candidateRatio = input.basePrice > 0
            ? Self.feelsLike(calculation.price.customerPrice, equalizationMultiplier: input.equalizationMultiplier, factor: resolved.factor) / input.basePrice
            : 1
        let floor = strategy.floor * input.basePrice * input.equalizationMultiplier
        let keepsCurrent = facts.isHolding
            || (calculation.raisedToFloor
                ? Self.isAtFloor(current, floor: floor)
                : !Self.isMeaningfulChange(from: current, to: calculation.price.customerPrice)
                || Self.matchesTarget(ratio: ratio)
                || !Self.movesCloser(from: ratio, to: candidateRatio))
        let price = keepsCurrent
            ? input.ladder.point(at: current) ?? calculator.offLadderPoint(current, territory: input.territory)
            : calculation.price
        let isUnchanged = (price.customerPrice - current).magnitude < Decimal(1) / 1000
        let feelsSuggested = Self.feelsLike(price.customerPrice, equalizationMultiplier: input.equalizationMultiplier, factor: resolved.factor)
        let base = calculator.baseFormat(baseTerritoryID: baseTerritoryID)
        let howSure = confidence(input, evidence: evidence, provenance: resolved.provenance)
        return Recommendation(
            price: price,
            currentPrice: current,
            isUnchanged: isUnchanged,
            isBaseTerritory: false,
            confidence: howSure.level,
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
            summary: summary(facts, keepsCurrent: keepsCurrent, current: current, input: input, calculation: calculation),
            steps: calculation.steps,
            calculation: calculation,
            howSureReason: howSure.reason,
            evidence: evidenceSummary(input, evidence: evidence, confidence: howSure)
        )
    }

    /// HowSure for the territory (`PriceConfidenceRule`).
    func confidence(_ input: PriceCalculationInput, evidence: SalesEvidence, provenance: PriceProvenance) -> PriceConfidence {
        let trust = indexTrust(territoryID: input.territory.id, provenance: provenance)
        return PriceConfidenceRule.evaluate(PriceConfidenceInput(
            territoryName: input.territory.name,
            availability: Self.salesState(evidence),
            indexTrust: trust.trust,
            indexEditionYear: trust.year,
            hasRealGrid: evidence.hasRealGrid,
            signal: evidence.signal,
            pooled: evidence.pooled,
            priorChange: evidence.priorChange,
            usesTrials: evidence.usesTrials,
            asOf: evidence.readThrough ?? asOf,
            priceTest: evidence.priceTest
        ))
    }

    /// The evidence's sales state, as far as it counts: evidence that can't
    /// read sales but says they're available is a key's role that can't.
    static func salesState(_ evidence: SalesEvidence) -> PricingSalesData.Availability {
        guard !evidence.canReadSales else { return evidence.availability }
        return evidence.availability == .available || evidence.availability == .noSalesYet ? .roleCannotRead : evidence.availability
    }

    // MARK: - Private

    /// How far the purchasing-power value behind the factor is real: the
    /// index's own trust, a region median is approximate, anything else
    /// (equalized, excluded) has no value.
    func indexTrust(territoryID: String, provenance: PriceProvenance) -> (trust: PriceIndexTrust, year: Int?) {
        switch provenance.kind {
        case let .index(source):
            let year = calculator.snapshot.index(source).map { Calendar.gmtGregorian.component(.year, from: $0.edition.date) }
            return (calculator.snapshot.trust(of: source, territoryID: territoryID, asOf: asOf), year)
        case .regionMedian:
            return (.approximate, nil)
        default:
            return (.missing, nil)
        }
    }

    /// The popover tip's and the Reason column's sales, when they count.
    private func evidenceSummary(_ input: PriceCalculationInput, evidence: SalesEvidence, confidence: PriceConfidence) -> PriceEvidenceSummary? {
        guard evidence.canReadSales else { return nil }
        let summary = PriceEvidenceSummary(
            territoryName: input.territory.name,
            recent: evidence.recentSignal,
            borrowedFrom: confidence.borrowedFrom,
            regionPageViews: evidence.pooled?.regionTotal.pageViews ?? 0,
            usesTrials: evidence.usesTrials
        )
        return summary.isEmpty ? nil : summary
    }

    /// What the sales evidence says, read once.
    private struct Facts {
        var availability: PricingSalesData.Availability
        /// The last 90 days.
        var signal: SalesSignal?
        var prior: PriorPriceChange?
        var canReadSales: Bool
        /// 300 page views and 10 trials, in the country or its pooled region.
        var hasEnoughSales: Bool
        /// Pooled when there's pooling, else the country's own.
        var conversion: Double?
        var reference: Double?
        /// The base territory's own 90-day conversion, for the basis line.
        var baseConversion: Double?
        var isSoftStep: Bool
        /// The step's intensity when soft: 1 − ½ × the country's own weight,
        /// in steps of 5%, so it moves from the purchasing-power target
        /// only as far as its own evidence goes.
        var softIntensity: Decimal
        var isHolding: Bool

        init(evidence: SalesEvidence, ratio: Decimal) {
            canReadSales = evidence.canReadSales
            availability = PriceRecommender.salesState(evidence)
            baseConversion = canReadSales ? evidence.baseSignal?.conversion : nil
            signal = canReadSales ? evidence.signal : nil
            prior = canReadSales ? evidence.priorChange : nil
            let ownIsEnough = signal.map { PriceConfidenceRule.meetsSample($0, usesTrials: evidence.usesTrials) } ?? false
            let regionIsEnough = (signal?.pageViews ?? 0) > 0
                && (evidence.pooled.map { PriceConfidenceRule.meetsSample($0.regionTotal, usesTrials: evidence.usesTrials) } ?? false)
            hasEnoughSales = canReadSales && (ownIsEnough || regionIsEnough)
            conversion = canReadSales ? evidence.pooled?.rate ?? signal?.conversion : nil
            reference = canReadSales ? evidence.basePooled?.rate ?? evidence.baseSignal?.conversion : nil
            let weight = ((evidence.pooled?.ownWeight ?? 1) * 20).rounded() / 20
            softIntensity = 1 - (1 - PriceRecommender.softStepIntensity) * Decimal(exactly: min(1, max(0, weight)))
            if hasEnoughSales, let conversion, let reference, softIntensity < 1 {
                isSoftStep = conversion >= PriceRecommender.softStepConversionShare * reference && ratio >= PriceRecommender.holdsBackRatio
            } else {
                isSoftStep = false
            }
            isHolding = prior.map { !$0.liftedStarts } ?? false
        }

        var hasFewStarts: Bool {
            guard hasEnoughSales, let conversion, let reference else { return false }
            return conversion < PriceRecommender.weakConversionShare * reference
        }
    }

    private func summary(
        _ facts: Facts,
        keepsCurrent: Bool,
        current: Decimal,
        input: PriceCalculationInput,
        calculation: PriceCalculation
    ) -> String {
        let price = CurrencyFormat.format(current, currency: input.territory.currencyCode)
        if facts.isHolding { return String(localized: "Holding at \(price)", comment: "kind:description") }
        if keepsCurrent { return String(localized: "Kept at \(price) · close to the target", comment: "kind:description") }
        return calculation.summary
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
        // The edition the factor came from ("World Bank 2025", "IMF, Oct 2026"),
        // else World Bank's for the region median and equalized lines.
        let edition = resolved.provenance.edition != nil ? resolved.provenance.label
            : calculator.snapshot.index(.worldBank)?.edition.provenanceLabel ?? PriceIndexSource.worldBank.shortName
        let level = resolved.factor.fixed(2)
        var power = String(localized: "Purchasing power: \(edition) price level \(level)", comment: "kind:other")
        switch resolved.provenance.kind {
        case .regionMedian: power = String(localized: "\(power) (region median, no World Bank data)", comment: "kind:description")
        case .equalized: power = String(localized: "\(power) (no World Bank data)", comment: "kind:other")
        default: break
        }
        var lines = [power]
        if let line = PricingSalesLine.basis(facts.availability) {
            lines.append(line)
        } else if let signal = facts.signal {
            let pageViews = PricingText.grouped(signal.pageViews)
            let conversion = PricingText.percent(signal.conversion ?? 0)
            var sales = String(localized: "Your sales, last 90 days: \(pageViews) page views · \(signal.starts) starts · \(conversion)", comment: "kind:other")
            if let reference = facts.baseConversion {
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
