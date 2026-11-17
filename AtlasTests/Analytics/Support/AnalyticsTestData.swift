//
//  AnalyticsTestData.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Small datasets for the Analytics tests: a few facts on chosen days.
enum AnalyticsTestData {
    static let through = AnalyticsDay(number: 20767)
    static let appID = "6450000001"

    /// One fact with these counts.
    static func fact(
        back: Int = 0, territory: String = "US", source: String = "App Store Search", device: String = "iPhone",
        impressions: Int = 0, views: Int = 0, downloads: Int = 0
    ) -> EngagementFact {
        var fact = EngagementFact(day: through.adding(-back), territory: territory, source: source, device: device)
        fact.impressions = impressions
        fact.pageViews = views
        fact.downloads = downloads
        return fact
    }

    static func event(
        _ kind: SubscriptionEventKind, _ quantity: Int, back: Int = 0, territory: String = "US", subscription: String = "Annual",
        periods: Int = 0, reason: String = ""
    ) -> SubscriptionEventFact {
        SubscriptionEventFact(
            day: through.adding(-back), appID: appID, kind: kind, subscription: subscription, territory: territory, device: "iPhone",
            paidPeriods: periods, reason: reason, quantity: quantity
        )
    }

    /// The design's Lumen: 28 days of 184,200 → 9,870 → 3,120 → 412 → 168
    /// after 28 days of 171,900 → 10,420 → 3,180 → 398 → 176, with a first
    /// day far enough back for both periods.
    static var lumen: AnalyticsDataset {
        AnalyticsDataset(
            appID: appID,
            appName: "Lumen Journal",
            engagement: [
                fact(impressions: 184_200, views: 9870, downloads: 3120),
                fact(back: 28, impressions: 171_900, views: 10420, downloads: 3180),
                fact(back: 60, impressions: 1, views: 0, downloads: 0),
            ],
            events: [
                event(.trialStart, 412), event(.paidFromTrial, 150, periods: 1), event(.paidStart, 18, periods: 1),
                event(.trialStart, 398, back: 28), event(.paidFromTrial, 160, back: 28, periods: 1), event(.paidStart, 16, back: 28, periods: 1),
            ],
            subscribers: [
                SubscriberFact(day: through, appID: appID, subscription: "Annual", territory: "US", charges: 100, refunds: 2, proceeds: 4920),
                SubscriberFact(day: through.adding(-28), appID: appID, subscription: "Annual", territory: "US", charges: 90, refunds: 0, proceeds: 4600),
            ]
        )
    }
}
