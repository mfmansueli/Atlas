//
//  BetaPrior.swift
//  Atlas
//

import Foundation

/// A Beta(α, β) prior over a conversion rate (page view → start), written
/// as its mean α ÷ (α + β) and its strength α + β: how many page views of
/// evidence the prior is worth.
struct BetaPrior: Hashable, Sendable {
    var mean: Double
    var strength: Double

    var alpha: Double { mean * strength }
    var beta: Double { (1 - mean) * strength }

    /// The posterior mean after `starts` of `pageViews`:
    /// (k + α) ÷ (n + α + β).
    func posteriorMean(starts: Int, pageViews: Int) -> Double {
        let views = Double(max(0, pageViews))
        let total = views + strength
        guard total > 0 else { return mean }
        return (Double(min(max(0, starts), max(0, pageViews))) + alpha) / total
    }

    /// The share of the posterior that is the sample's own: n ÷ (n + α + β).
    func ownWeight(pageViews: Int) -> Double {
        let views = Double(max(0, pageViews))
        let total = views + strength
        return total > 0 ? views / total : 0
    }

    /// An empirical-Bayes prior from several countries' samples, by an
    /// approximate method of moments:
    ///
    /// - mean m = Σk ÷ Σn (every page view weighs the same);
    /// - spread between countries τ² = s² − m(1 − m)·c ÷ Σn, where s² is the
    ///   page-view-weighted variance of the countries' rates and the second
    ///   term is what binomial noise alone would give over c countries;
    /// - strength M = m(1 − m) ÷ τ² − 1, kept within
    ///   [`minimumStrength`, `maximumStrength`].
    ///
    /// With no spread beyond noise the countries look alike, so M is the
    /// maximum. With fewer than two countries, or no starts at all, the
    /// spread can't be measured and M is the minimum. Nil without page views.
    static func methodOfMoments(_ samples: [SalesSignal], minimumStrength: Double, maximumStrength: Double) -> BetaPrior? {
        let observed = samples.filter { $0.pageViews > 0 }
        let views = observed.reduce(0) { $0 + $1.pageViews }
        guard views > 0 else { return nil }
        let starts = observed.reduce(0) { $0 + min(max(0, $1.starts), $1.pageViews) }
        let total = Double(views)
        let mean = Double(starts) / total
        guard observed.count >= 2, mean > 0, mean < 1 else {
            return BetaPrior(mean: mean, strength: minimumStrength)
        }
        let variance = observed.reduce(0.0) { sum, signal in
            let rate = Double(min(max(0, signal.starts), signal.pageViews)) / Double(signal.pageViews)
            return sum + Double(signal.pageViews) * (rate - mean) * (rate - mean)
        } / total
        let noise = mean * (1 - mean) * Double(observed.count) / total
        let spread = variance - noise
        guard spread > 0 else { return BetaPrior(mean: mean, strength: maximumStrength) }
        let strength = mean * (1 - mean) / spread - 1
        return BetaPrior(mean: mean, strength: min(maximumStrength, max(minimumStrength, strength)))
    }
}
