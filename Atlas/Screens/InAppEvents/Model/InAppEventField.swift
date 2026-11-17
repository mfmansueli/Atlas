//
//  InAppEventField.swift
//  Atlas
//

import Foundation

/// The three texts an In-App Event has in each language.
enum InAppEventField: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case name
    case shortDescription
    case longDescription

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: String(localized: "Event Name")
        case .shortDescription: String(localized: "Short Description")
        case .longDescription: String(localized: "Long Description")
        }
    }

    /// Apple's limits: 30, 50 and 120 characters.
    var limit: Int {
        switch self {
        case .name: 30
        case .shortDescription: 50
        case .longDescription: 120
        }
    }

    var isMultiline: Bool { self == .longDescription }
}
