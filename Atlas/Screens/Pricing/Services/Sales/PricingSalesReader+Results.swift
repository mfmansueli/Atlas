//
//  PricingSalesReader+Results.swift
//  Atlas
//

import Foundation

/// What Results and the schedule's consent warnings read from the same
/// archives.
extension PricingSalesReader {
    /// Each territory's 28 days before a change on `date` and the 28 from
    /// it (the change day is the first day after), with the days the
    /// reports cover on each side; nil when sales can't be read.
    func comparison(for product: PricingProduct, territoryIDs: [String], changedOn date: Date) -> [String: SalesComparison]? {
        let availability = availability(for: product)
        guard availability == .available || availability == .noSalesYet else { return nil }
        let day = AnalyticsDay(date)
        let days = ResultsEvaluator.windowDays
        let beforeRange = day.adding(-days)...day.adding(-1)
        let afterRange = day...day.adding(days - 1)
        let before = signals(for: product, in: beforeRange)
        let after = signals(for: product, in: afterRange)
        let beforeDays = coveredDays(beforeRange)
        let afterDays = coveredDays(afterRange)
        var result: [String: SalesComparison] = [:]
        for territoryID in territoryIDs {
            result[territoryID] = SalesComparison(
                before: SalesWindow(signal: before[territoryID] ?? .zero, days: beforeDays),
                after: SalesWindow(signal: after[territoryID] ?? .zero, days: afterDays)
            )
        }
        return result
    }

    /// Active subscriptions, paid and in a trial, per territory (alpha-3) on
    /// the newest day the Subscription report has the product; nil when
    /// sales can't be read.
    func subscribers(for product: PricingProduct) -> [String: Int]? {
        let availability = availability(for: product)
        guard availability == .available || availability == .noSalesYet else { return nil }
        let facts = input.active.filter { Self.matches(subscriptionID: $0.subscriptionID, name: $0.subscription, product: product) }
        guard let last = facts.map(\.day).max() else { return [:] }
        var counts: [String: Int] = [:]
        for fact in facts where fact.day == last {
            guard let territoryID = territories.territory(alpha2: fact.territory)?.id else { continue }
            counts[territoryID, default: 0] += fact.paid + fact.trials
        }
        return counts.filter { $0.value > 0 }
    }
}
