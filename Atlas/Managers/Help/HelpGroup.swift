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

    /// The group's symbol in Help's sidebar and home (board 49 after the SF
    /// Symbols pass).
    var systemImage: String {
        switch self {
        case .start: "flag"
        case .listing: "doc.text"
        case .after: "chart.bar"
        case .atlas: "macwindow"
        }
    }
}
