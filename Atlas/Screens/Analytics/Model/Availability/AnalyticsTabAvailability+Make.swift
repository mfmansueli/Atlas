//
//  AnalyticsTabAvailability+Make.swift
//  Atlas
//

import Foundation

extension AnalyticsTabAvailability {
    /// Why `tab` has nothing to show yet, from what the dataset holds
    /// (`now` for the Pacific day):
    ///
    /// - Subscriptions: `SubscriptionsSoFar` (nothing sold, trials only,
    ///   fewer than 5 people for rates).
    /// - Stability: `CrashesSoFar` (a version too new, an app too new, no
    ///   crashes reported).
    /// - Break It Down: "Not enough people yet" for a new app with fewer
    ///   than 5 downloads in all, since Apple leaves out every row under 5
    ///   people.
    /// - Overview, What to Try and After Changes have their own states
    ///   (counts for a quiet app, "Nothing yet", "No pushes yet").
    static func make(_ tab: AnalyticsTab, dataset: AnalyticsDataset, now: Date) -> AnalyticsTabAvailability {
        switch tab {
        case .subscriptions: SubscriptionsSoFar.make(dataset, now: now).availability
        case .stability: CrashesSoFar.make(dataset).availability
        case .breakDown: hasTooFewPeopleForRows(dataset) ? .notEnoughPeople : .available
        case .overview, .whatToTry, .afterChanges: .available
        }
    }

    /// A new app (less than a full period of data) with fewer than 5
    /// downloads: every row Break It Down would show is under Apple's
    /// minimum.
    static func hasTooFewPeopleForRows(_ dataset: AnalyticsDataset) -> Bool {
        guard (1..<AnalyticsAvailability.newAppDays).contains(dataset.dayCount) else { return false }
        return dataset.engagement.reduce(0) { $0 + $1.downloads } < minimumPeople
    }
}
