//
//  AppAvailabilityProblem.swift
//  Atlas
//

import Foundation

/// Why App Store Connect would refuse an availability: nowhere to sell
/// it, or a pre-order release date outside what Apple allows.
enum AppAvailabilityProblem: Hashable, Sendable {
    case noTerritory
    case invalidReleaseDate
    case releaseDateTooSoon(earliest: String)
    case releaseDateTooLate(latest: String)

    var message: String {
        switch self {
        case .noTerritory:
            String(localized: "Choose at least one country or region.")
        case .invalidReleaseDate:
            String(localized: "Enter the release date like 2026-12-20.")
        case let .releaseDateTooSoon(earliest):
            String(localized: "A pre-order’s release date is at least \(AppAvailabilityRules.preOrderMinimumDays) days away: \(earliest) or later.")
        case let .releaseDateTooLate(latest):
            String(localized: "A pre-order’s release date is at most \(AppAvailabilityRules.preOrderMaximumDays) days away: \(latest) or earlier.")
        }
    }
}
