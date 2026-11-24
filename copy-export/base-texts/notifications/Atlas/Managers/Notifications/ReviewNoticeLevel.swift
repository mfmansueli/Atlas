//
//  ReviewNoticeLevel.swift
//  Atlas
//

import Foundation

/// Settings → Notifications → "New reviews": which new reviews Atlas
/// tells you about.
enum ReviewNoticeLevel: String, CaseIterable, Identifiable, Sendable {
    case never
    case lowRatings
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: String(localized: "Never")
        case .lowRatings: String(localized: "3 stars or lower")
        case .all: String(localized: "Every review")
        }
    }

    func includes(rating: Int) -> Bool {
        switch self {
        case .never: false
        case .lowRatings: rating <= 3
        case .all: true
        }
    }
}
