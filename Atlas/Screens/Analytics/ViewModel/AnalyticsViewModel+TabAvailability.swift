//
//  AnalyticsViewModel+TabAvailability.swift
//  Atlas
//

import Foundation

extension AnalyticsViewModel {
    /// Why `tab` has nothing to show yet, or `.available` (Agent 5 fills
    /// in the rules; the strip, the views and the Overview's KPIs read it).
    func availability(for _: AnalyticsTab) -> AnalyticsTabAvailability {
        .available
    }
}
