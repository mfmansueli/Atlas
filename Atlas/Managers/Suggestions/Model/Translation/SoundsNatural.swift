//
//  SoundsNatural.swift
//  Atlas
//

import Foundation

/// How natural a suggestion in another language reads to someone who
/// speaks it (board 77), as the assistant judged it on a second read as a
/// native speaker. MCP sends it as `sounds`: `native`, `translated` or
/// `off` (1, 2 or 3 are read the same way, 3 being native). Cards show it
/// with fixed words, always in the same place, like how sure.
enum SoundsNatural: String, CaseIterable, Hashable, Codable, Sendable {
    /// Reads as if it was written in the language.
    case native
    /// The meaning is right, but it's said the way the original says it.
    case translated
    /// A word changes the meaning, or there's a mistake.
    case off

    /// `native`, `translated` or `off`, or 3, 2 or 1 as MCP may send it.
    init?(mcpValue value: JSONValue) {
        if let name = value.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            self.init(rawValue: name)
        } else if let number = value.intValue {
            switch number {
            case 3: self = .native
            case 2: self = .translated
            case 1: self = .off
            default: return nil
            }
        } else {
            return nil
        }
    }

    /// The Sounds line's fixed words.
    var word: String {
        switch self {
        case .native: String(localized: "Sounds native", comment: "kind:badge")
        case .translated: String(localized: "Sounds translated", comment: "kind:badge")
        case .off: String(localized: "Sounds off", comment: "kind:badge")
        }
    }
}
