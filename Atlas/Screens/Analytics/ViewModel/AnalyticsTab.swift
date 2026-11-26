//
//  AnalyticsTab.swift
//  Atlas
//

import Foundation

/// The views inside Analytics, in the order of the card strip under the
/// header (README-DS §16, board 92).
enum AnalyticsTab: String, Hashable, Sendable, CaseIterable, Identifiable {
    case overview
    case breakDown
    case whatToTry
    case afterChanges
    case subscriptions
    /// Crashes by version.
    case stability

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: String(localized: "Overview", comment: "kind:tab · Analytics view")
        case .breakDown: String(localized: "Break It Down", comment: "kind:tab · Analytics view")
        case .whatToTry: String(localized: "What to Try", comment: "kind:tab · Analytics view")
        case .afterChanges: String(localized: "After Changes", comment: "kind:tab · Analytics view")
        case .subscriptions: String(localized: "Subscriptions", comment: "kind:tab · Analytics view")
        case .stability: String(localized: "Stability", comment: "kind:tab · Analytics view")
        }
    }

    /// The card's SF Symbol in the strip.
    var systemImage: String {
        switch self {
        case .overview: "chart.bar.xaxis"
        case .breakDown: "tablecells"
        case .whatToTry: "lightbulb"
        case .afterChanges: "clock.arrow.circlepath"
        case .subscriptions: "arrow.triangle.2.circlepath"
        case .stability: "waveform.path.ecg"
        }
    }
}
