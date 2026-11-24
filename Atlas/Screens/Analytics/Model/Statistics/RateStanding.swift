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

    /// The SF Symbol drawn beside the rate (README-DS §13, the Analytics
    /// board), always with `title` for VoiceOver and the tooltip.
    var systemImage: String {
        switch self {
        case .better: "arrowtriangle.up.fill"
        case .worse: "arrowtriangle.down.fill"
        case .same: "equal"
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
