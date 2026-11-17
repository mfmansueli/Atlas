//
//  FunnelStep.swift
//  Atlas
//

import Foundation

/// One step of the funnel as drawn: its count, the rate from the step
/// before, and both against the previous period.
struct FunnelStep: Hashable, Sendable, Identifiable {
    var stage: FunnelStage
    var count: Int?
    /// "+7%" against the previous period; nil without one.
    var change: String?
    var gap: FunnelGap?
    /// From the step before; `.missing` on the first step.
    var rate: AnalyticsRate
    /// The rate against the previous period; nil on the first step or
    /// without an earlier period.
    var comparison: PeriodComparison?

    var id: FunnelStage { stage }

    var countText: String { count.map(AnalyticsText.count) ?? "—" }

    /// "Product page views: 9,870, −5% against the previous period".
    var accessibilityText: String {
        if let gap { return "\(stage.title): \(gap.text)" }
        guard let change else { return "\(stage.title): \(countText)" }
        return String(localized: "\(stage.title): \(countText), \(change) against the previous period")
    }
}
