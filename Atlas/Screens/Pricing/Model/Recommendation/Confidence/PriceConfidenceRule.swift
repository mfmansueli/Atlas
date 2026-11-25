//
//  PriceConfidenceRule.swift
//  Atlas
//

import Foundation

/// HowSure for one country's price suggestion (Phase 5), each level with
/// its reason:
///
/// - **Not very sure**: purchasing power only (no sales read, none yet,
///   too few), or the index value isn't real published data
///   (`PriceIndexTrust` approximate, stale or missing), or the price grid
///   is simulated (`ProductPriceSheet.hasRealGrid` false).
/// - **Fairly sure**: a real index and grid, plus at least
///   `minimumPageViews` page views and `minimumTrials` trial starts in 90
///   days, in the country or, for a thin country with page views of its
///   own, in its pooled region (`PooledConversion.regionTotal`).
/// - **Sure**: an earlier change there with `minimumDaysEachSide` days on
///   each side, at least `minimumStartsEachSide` starts on each side, and a
///   90% range for the effect on conversion that excludes zero.
///
/// The 28 days before a change are the ones Atlas keeps with it, so only
/// the days after are counted, up to `asOf`.
enum PriceConfidenceRule {
    static let minimumPageViews = 300
    static let minimumTrials = 10
    static let minimumStartsEachSide = 30
    static let minimumDaysEachSide = 28

    static func evaluate(_ input: PriceConfidenceInput) -> PriceConfidence {
        if let reason = salesStateReason(input.availability) { return .notVerySure(reason) }
        if let reason = trustReason(input.indexTrust, year: input.indexEditionYear) { return .notVerySure(reason) }
        guard input.hasRealGrid else {
            return .notVerySure(String(localized: "Apple’s price points for this country aren’t read yet.", comment: "kind:description"))
        }
        if let sure = sure(input) { return sure }
        if let fairly = fairly(input) { return fairly }
        return .notVerySure(tooFewReason(input))
    }

    /// Trial starts when the product has trials, else every start.
    static func counted(_ signal: SalesSignal, usesTrials: Bool) -> Int {
        usesTrials ? signal.trialStarts : signal.starts
    }

    /// Enough for Fairly sure: 300 page views and 10 trials.
    static func meetsSample(_ signal: SalesSignal, usesTrials: Bool) -> Bool {
        signal.pageViews >= minimumPageViews && counted(signal, usesTrials: usesTrials) >= minimumTrials
    }

    // MARK: - Private

    private static func salesStateReason(_ availability: PricingSalesData.Availability) -> String? {
        switch availability {
        case .available: nil
        case .noSalesYet: String(localized: "Purchasing power only: no sales yet.", comment: "kind:description")
        case .roleCannotRead: String(localized: "Purchasing power only: this key’s role can’t read sales.", comment: "kind:description")
        case .turnedOff: String(localized: "Purchasing power only: sales data is off in Settings.", comment: "kind:description")
        case .notRead: String(localized: "Purchasing power only: Atlas hasn’t read your sales yet.", comment: "kind:description")
        }
    }

    private static func trustReason(_ trust: PriceIndexTrust, year: Int?) -> String? {
        switch trust {
        case .exact, .fallback:
            return nil
        case .approximate:
            return String(localized: "Purchasing power here is an estimate, not a published figure.", comment: "kind:description")
        case .stale:
            guard let year else {
                return String(localized: "Purchasing power from an index edition over 18 months old.", comment: "kind:description")
            }
            return String(localized: "Purchasing power from the \(String(year)) edition, too old to be sure.", comment: "kind:description")
        case .missing:
            return String(localized: "No purchasing power figure for this country.", comment: "kind:description")
        }
    }

    private static func sure(_ input: PriceConfidenceInput) -> PriceConfidence? {
        if let measured = priorChangeSure(input) { return measured }
        return priceTestSure(input)
    }

    /// A finished price test in the region counts as a measured change
    /// (board 76): 30 starts on each side and a 90% range clear of zero.
    private static func priceTestSure(_ input: PriceConfidenceInput) -> PriceConfidence? {
        guard let test = input.priceTest, test.excludesZero,
              test.before.starts >= minimumStartsEachSide, test.during.starts >= minimumStartsEachSide
        else { return nil }
        let low = PriceConfidenceText.points(test.low)
        let high = PriceConfidenceText.points(test.high)
        let reason = String(
            localized: "Your \(test.region.title) price test: \(test.before.starts) → \(test.during.starts) starts, 90% range \(low) to \(high) points.",
            comment: "kind:description"
        )
        return PriceConfidence(level: .high, reason: reason, effect: test.effect)
    }

    private static func priorChangeSure(_ input: PriceConfidenceInput) -> PriceConfidence? {
        guard let prior = input.priorChange,
              PriceConfidenceText.days(from: prior.date, to: input.asOf) >= minimumDaysEachSide,
              prior.before.starts >= minimumStartsEachSide, prior.after.starts >= minimumStartsEachSide,
              let effect = PriorChangeEffect(before: prior.before, after: prior.after), effect.excludesZero
        else { return nil }
        let month = PriceConfidenceText.month(prior.date)
        let low = PriceConfidenceText.points(effect.low)
        let high = PriceConfidenceText.points(effect.high)
        let reason = String(
            localized: "Your \(month) change: \(prior.before.starts) → \(prior.after.starts) starts, 90% range \(low) to \(high) points.",
            comment: "kind:description"
        )
        return PriceConfidence(level: .high, reason: reason, effect: effect)
    }

    private static func fairly(_ input: PriceConfidenceInput) -> PriceConfidence? {
        let own = input.signal ?? .zero
        if meetsSample(own, usesTrials: input.usesTrials) {
            return PriceConfidence(level: .medium, reason: sampleLine(input.territoryName, own, usesTrials: input.usesTrials))
        }
        guard own.pageViews > 0, let pooled = input.pooled, meetsSample(pooled.regionTotal, usesTrials: input.usesTrials) else { return nil }
        return PriceConfidence(
            level: .medium,
            reason: sampleLine(pooled.region.title, pooled.regionTotal, usesTrials: input.usesTrials),
            borrowedFrom: pooled.region
        )
    }

    /// "Europe: 2,100 page views and 24 trials in 90 days."
    private static func sampleLine(_ name: String, _ signal: SalesSignal, usesTrials: Bool) -> String {
        let views = PriceConfidenceText.pageViews(signal.pageViews)
        let starts = PriceConfidenceText.starts(counted(signal, usesTrials: usesTrials), trials: usesTrials)
        return String(localized: "\(name): \(views) and \(starts) in 90 days.", comment: "kind:description")
    }

    private static func tooFewReason(_ input: PriceConfidenceInput) -> String {
        guard let signal = input.signal, signal.pageViews > 0 else {
            return String(localized: "Purchasing power only: no page views here in 90 days.", comment: "kind:description")
        }
        let views = PriceConfidenceText.pageViews(signal.pageViews)
        let starts = PriceConfidenceText.starts(counted(signal, usesTrials: input.usesTrials), trials: input.usesTrials)
        return String(localized: "Too few yet: \(views) and \(starts) in 90 days.", comment: "kind:description")
    }
}
