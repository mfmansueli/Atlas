//
//  AnalyticsViewModel+Availability.swift
//  Atlas
//

import Foundation

extension AnalyticsViewModel {
    /// What Analytics can show as a whole (README-DS §16).
    var availability: AnalyticsAvailability {
        AnalyticsAvailability.make(AnalyticsAvailability.Inputs(
            setup: setup,
            activity: activity,
            hasData: funnel != nil,
            askedOn: askedOn,
            sellsSubscriptions: sellsSubscriptions,
            salesState: dataset.salesState,
            engagementState: dataset.engagementState,
            staleDays: staleDays,
            firstDay: dataset.firstDay?.date,
            dayCount: dataset.dayCount
        ))
    }
}
