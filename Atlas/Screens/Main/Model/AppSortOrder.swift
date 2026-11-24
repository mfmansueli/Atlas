//
//  AppSortOrder.swift
//  Atlas
//

import Foundation

/// The sidebar's sort menu.
enum AppSortOrder: String, CaseIterable, Identifiable, Sendable {
    case name
    case unpushedChanges
    case lowestCoverage
    case mostSuggestions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: String(localized: "Name")
        case .unpushedChanges: String(localized: "Unpushed Changes")
        case .lowestCoverage: String(localized: "Lowest Locale Coverage")
        case .mostSuggestions: String(localized: "Most Price Suggestions")
        }
    }
}
