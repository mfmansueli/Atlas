//
//  RateStanding.swift
//  Atlas
//

import Foundation

/// Where a rate sits against the app's average, said only when the rate's
/// whole 90% range is above or below it.
enum RateStanding: String, Hashable, Sendable, Codable {
    case better
    case worse
    /// The range includes the average: the difference could be chance.
    case same

    /// ▲ ▼ ≈, always shown with `title` for VoiceOver and the tooltip.
    var mark: String {
        switch self {
        case .better: "▲"
        case .worse: "▼"
        case .same: "≈"
        }
    }

    var title: String {
        switch self {
        case .better: String(localized: "Better than average")
        case .worse: String(localized: "Worse than average")
        case .same: String(localized: "About average")
        }
    }
}
