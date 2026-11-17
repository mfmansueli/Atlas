//
//  EngagementFact.swift
//  Atlas
//

import Foundation

/// One day's App Store numbers for one territory, source, device and
/// product page, added up from Apple's Discovery and Engagement and
/// Downloads reports.
struct EngagementFact: Hashable, Sendable, Codable {
    var day: AnalyticsDay
    /// ISO alpha-2, e.g. "DE"; "" when Apple didn't say.
    var territory: String
    /// Apple's Source Type, e.g. "App Store search".
    var source: String
    /// Apple's Device, e.g. "iPhone".
    var device: String
    /// The product page's name, from the Detailed reports only; "" in the
    /// Standard ones.
    var page: String = ""
    /// Times the app showed in search, browse or a link preview.
    var impressions = 0
    var pageViews = 0
    /// First-time downloads.
    var downloads = 0
    var redownloads = 0

    private enum CodingKeys: String, CodingKey {
        case day = "d", territory = "t", source = "s", device = "v", page = "p"
        case impressions = "i", pageViews = "w", downloads = "n", redownloads = "r"
    }

    /// Everything but the counts: facts with the same key add up.
    var key: EngagementFact {
        EngagementFact(day: day, territory: territory, source: source, device: device, page: page)
    }

    mutating func add(_ other: EngagementFact) {
        impressions += other.impressions
        pageViews += other.pageViews
        downloads += other.downloads
        redownloads += other.redownloads
    }

    /// Facts with the same key merged into one, in a stable order.
    static func merged(_ facts: [EngagementFact]) -> [EngagementFact] {
        var byKey: [EngagementFact: EngagementFact] = [:]
        for fact in facts {
            byKey[fact.key, default: fact.key].add(fact)
        }
        return byKey.values.sorted {
            ($0.day, $0.territory, $0.source, $0.device, $0.page) < ($1.day, $1.territory, $1.source, $1.device, $1.page)
        }
    }
}
