//
//  BreakdownDimension.swift
//  Atlas
//

import Foundation

/// What Break It Down splits the funnel by.
enum BreakdownDimension: String, Hashable, Sendable, CaseIterable, Identifiable, Codable {
    case territory
    case language
    case source
    case device
    case productPage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .territory: String(localized: "Territory")
        case .language: String(localized: "Language")
        case .source: String(localized: "Source")
        case .device: String(localized: "Device")
        case .productPage: String(localized: "Product Page")
        }
    }

    /// Whether Apple links sales to this split.
    var hasSales: Bool {
        switch self {
        case .territory, .language, .device: true
        case .source, .productPage: false
        }
    }
}
