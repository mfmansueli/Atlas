//
//  ProductPageArrival.swift
//  Atlas
//

import Foundation

/// Where a page's visitors came from over its 28 days: a campaign link
/// (its `ct` token) or the app or website that linked to it (Apple's Source
/// Info), from the Detailed reports. This is where the page's link is used.
struct ProductPageArrival: Hashable, Sendable, Identifiable {
    enum Kind: String, Hashable, Sendable {
        case campaign
        case referrer

        var order: Int { self == .campaign ? 0 : 1 }
    }

    var kind: Kind
    var name: String
    var pageViews = 0
    var downloads = 0

    var id: String { "\(kind.rawValue).\(name)" }

    /// "Campaign “spring_ig”", "instagram.com".
    var title: String {
        switch kind {
        case .campaign: String(localized: "Campaign “\(name)”")
        case .referrer: name
        }
    }

    /// A page's arrivals, the most page views first, then downloads; on a
    /// tie a campaign (the link someone made) before a referrer, then by
    /// name. From facts already narrowed to that page and period.
    static func make(from facts: [EngagementFact]) -> [ProductPageArrival] {
        var byID: [String: ProductPageArrival] = [:]
        func add(_ kind: Kind, _ name: String?, _ fact: EngagementFact) {
            guard let name else { return }
            let arrival = ProductPageArrival(kind: kind, name: name)
            byID[arrival.id, default: arrival].pageViews += fact.pageViews
            byID[arrival.id, default: arrival].downloads += fact.downloads
        }
        for fact in facts {
            add(.campaign, fact.campaign, fact)
            add(.referrer, fact.referrer, fact)
        }
        return byID.values
            .filter { $0.pageViews + $0.downloads > 0 }
            .sorted { ($1.pageViews, $1.downloads, $0.kind.order, $0.name) < ($0.pageViews, $0.downloads, $1.kind.order, $1.name) }
    }
}
