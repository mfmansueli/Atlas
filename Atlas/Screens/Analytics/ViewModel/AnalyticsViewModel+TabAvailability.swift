//
//  AnalyticsViewModel+TabAvailability.swift
//  Atlas
//

import Foundation

extension AnalyticsViewModel {
    /// Why `tab` has nothing to show yet, or `.available`: the strip's
    /// card, the view and the Overview's KPI say the same case
    /// (`AnalyticsTabAvailability.make(_:dataset:now:)` has the rules).
    func availability(for tab: AnalyticsTab) -> AnalyticsTabAvailability {
        AnalyticsTabAvailability.make(tab, dataset: dataset, now: store.now())
    }

    /// Subscriptions since the first sale, for its empty states.
    var subscriptionsSoFar: SubscriptionsSoFar {
        SubscriptionsSoFar.make(dataset, now: store.now())
    }

    /// Crashes so far, for Stability's empty states.
    var crashesSoFar: CrashesSoFar {
        CrashesSoFar.make(dataset)
    }

    /// What Subscriptions says while it has nothing to show; nil when it
    /// has.
    var subscriptionsEmptyContent: AnalyticsEmptyContent? {
        AnalyticsEmptyContent.subscriptions(subscriptionsSoFar, appName: app.name)
    }

    /// What Stability says while it has nothing to show; nil when it has.
    var stabilityEmptyContent: AnalyticsEmptyContent? {
        AnalyticsEmptyContent.stability(crashesSoFar, appName: app.name)
    }
}
