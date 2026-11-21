//
//  ProductPageNumbers.swift
//  Atlas
//

import Foundation

/// A page's funnel over the last 28 days, from the same daily numbers as
/// Analytics → Break It Down → Product Page, so the two agree.
struct ProductPageNumbers: Hashable, Sendable {
    /// What Apple's reports call the default page.
    static let defaultPageName = "Default product page"
    /// The period, the same as Analytics' default.
    static let days = 28
    /// Fewer page views than this is too few to compare a rate with the
    /// default page's.
    static let fewestViewsToCompare = 200

    var impressions = 0
    var pageViews = 0
    var downloads = 0
    /// Where its visitors came from, the most first: campaign links and
    /// the apps and websites that link to it.
    var arrivals: [ProductPageArrival] = []

    /// Downloads out of page views, 0–100; nil without views.
    var downloadRate: Double? {
        pageViews > 0 ? Double(downloads) / Double(pageViews) * 100 : nil
    }

    /// Each page's numbers by the name Apple's reports give it, over the 28
    /// days ending on the newest day there is. Nil when there are none.
    static func make(from facts: [EngagementFact]) -> (byPage: [String: ProductPageNumbers], through: AnalyticsDay)? {
        guard let last = facts.map(\.day).max() else { return nil }
        let period = AnalyticsPeriod(ending: last, length: days)
        var byPage: [String: ProductPageNumbers] = [:]
        let inPeriod = facts.filter { period.contains($0.day) && !$0.page.isEmpty }
        for fact in inPeriod {
            byPage[fact.page, default: ProductPageNumbers()].impressions += fact.impressions
            byPage[fact.page, default: ProductPageNumbers()].pageViews += fact.pageViews
            byPage[fact.page, default: ProductPageNumbers()].downloads += fact.downloads
        }
        for (page, pageFacts) in Dictionary(grouping: inPeriod, by: \.page) {
            byPage[page]?.arrivals = ProductPageArrival.make(from: pageFacts)
        }
        return (byPage, last)
    }
}
