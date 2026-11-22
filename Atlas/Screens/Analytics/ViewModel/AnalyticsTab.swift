//
//  AnalyticsTab.swift
//  Atlas
//

import Foundation

/// The views inside Analytics.
enum AnalyticsTab: String, Hashable, Sendable, CaseIterable, Identifiable {
    case funnel
    case breakdown
    case findings
    case changes
    case subscriptions
    /// Crashes of the newest version; shown once Apple sent crash rows.
    case stability

    var id: String { rawValue }

    var title: String {
        switch self {
        case .funnel: String(localized: "Funnel")
        case .breakdown: String(localized: "Break It Down")
        case .findings: String(localized: "What to Try")
        case .changes: String(localized: "After Changes")
        case .subscriptions: String(localized: "Subscriptions")
        case .stability: String(localized: "Stability")
        }
    }
}
