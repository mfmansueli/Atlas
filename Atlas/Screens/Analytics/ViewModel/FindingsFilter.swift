//
//  FindingsFilter.swift
//  Atlas
//

import Foundation

/// Which findings What to Try lists.
enum FindingsFilter: String, Hashable, Sendable, CaseIterable, Identifiable {
    case open
    case actedOn
    case dismissed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: String(localized: "Open")
        case .actedOn: String(localized: "Acted On")
        case .dismissed: String(localized: "Dismissed")
        }
    }
}
