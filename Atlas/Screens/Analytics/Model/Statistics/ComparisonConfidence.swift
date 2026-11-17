//
//  ComparisonConfidence.swift
//  Atlas
//

import Foundation

/// How sure a difference between two periods is (two-proportion test).
enum ComparisonConfidence: String, Hashable, Sendable, Codable {
    /// Beyond 99%.
    case sure
    /// Beyond 90%.
    case fairlySure

    var title: String {
        switch self {
        case .sure: String(localized: "sure")
        case .fairlySure: String(localized: "fairly sure")
        }
    }
}
