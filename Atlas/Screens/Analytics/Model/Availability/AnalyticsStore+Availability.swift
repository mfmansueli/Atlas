//
//  AnalyticsStore+Availability.swift
//  Atlas
//

import Foundation

extension AnalyticsStore {
    /// What Analytics can show for `appID`, from what the store knows,
    /// without the section's view model: the sidebar's findings badge and
    /// the toolbar's line read it while Analytics isn't open. Until Pricing
    /// says otherwise the app is taken to sell a subscription, as the
    /// section does.
    func availability(for appID: StoreApp.ID, sellsSubscriptions: Bool = true) -> AnalyticsAvailability {
        let archive = archive(for: appID)
        let engagementDays = archive.facts.map(\.day)
        let salesDays = sales.events.filter { $0.appID == appID }.map(\.day)
        let through = engagementDays.max() ?? salesDays.max()
        let first = engagementDays.min() ?? salesDays.min()
        let dayCount = if let first, let through { through.number - first.number + 1 } else { 0 }
        return AnalyticsAvailability.make(AnalyticsAvailability.Inputs(
            setup: setup(for: appID),
            activity: activity(for: appID),
            hasData: through != nil,
            askedOn: record(for: appID).askedOn,
            sellsSubscriptions: sellsSubscriptions,
            salesState: salesState,
            engagementState: archive.isEmpty ? .waiting(asked: record(for: appID).askedOn) : .ready,
            staleDays: staleDays(through: through),
            firstDay: first?.date,
            dayCount: dayCount
        ))
    }

    /// New findings for the sidebar's grey count: none before the first
    /// reports (README-DS §16).
    func findingsBadgeCount(for appID: StoreApp.ID) -> Int {
        availability(for: appID).showsFindingsBadge ? newFindingCount(for: appID) : 0
    }
}
