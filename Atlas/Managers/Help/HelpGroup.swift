//
//  HelpGroup.swift
//  Atlas
//

import Foundation

/// Where Atlas Help lists an article (board 49).
enum HelpGroup: String, CaseIterable, Identifiable, Sendable {
    case start
    case listing
    case after
    case atlas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start: String(localized: "Start here")
        case .listing: String(localized: "Store listing")
        case .after: String(localized: "After release")
        case .atlas: String(localized: "Atlas")
        }
    }
}
