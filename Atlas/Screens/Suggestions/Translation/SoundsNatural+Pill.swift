//
//  SoundsNatural+Pill.swift
//  Atlas
//

import Foundation

extension SoundsNatural {
    /// Green, grey or amber (README-DS §1: state colours describe state).
    var pillStyle: PillStyle {
        switch self {
        case .native: .ok
        case .translated: .neutral
        case .off: .warning
        }
    }
}
