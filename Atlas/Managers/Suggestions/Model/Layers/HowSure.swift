//
//  HowSure.swift
//  Atlas
//

import Foundation

/// How sure an assistant is of a suggestion, 1–3 as MCP sends it
/// (`confidence`). Cards show it as the three-step how-sure meter with
/// fixed words (README-DS §9).
enum HowSure: Int, CaseIterable, Hashable, Codable, Sendable, Comparable {
    case notVerySure = 1
    case fairlySure = 2
    case sure = 3

    /// The meter's word, which VoiceOver reads and the tooltip shows.
    var word: String {
        switch self {
        case .notVerySure: String(localized: "Not very sure", comment: "kind:accessibility-label")
        case .fairlySure: String(localized: "Fairly sure", comment: "kind:accessibility-label")
        case .sure: String(localized: "Sure", comment: "kind:accessibility-label")
        }
    }

    /// Filled steps of the three.
    var steps: Int { rawValue }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
