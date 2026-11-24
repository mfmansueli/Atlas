//
//  NominationField.swift
//  Atlas
//

import Foundation

/// A part of a nomination someone can change, for "what changed" lines and
/// suggestions.
enum NominationField: String, CaseIterable, Hashable, Codable, Sendable {
    case type
    case name
    case description
    case dates
    case devices
    case languages
    case countries
    case preOrder
    case events
    case materials
    case notes
    case apps

    var title: String {
        switch self {
        case .type: String(localized: "Type", comment: "kind:field-label")
        case .name: String(localized: "Name", comment: "kind:field-label")
        case .description: String(localized: "Description", comment: "kind:field-label")
        case .dates: String(localized: "Dates", comment: "kind:field-label")
        case .devices: String(localized: "Devices", comment: "kind:field-label")
        case .languages: String(localized: "Languages", comment: "kind:field-label")
        case .countries: String(localized: "Countries and regions", comment: "kind:field-label")
        case .preOrder: String(localized: "Pre-order", comment: "kind:field-label")
        case .events: String(localized: "Linked In-App Events", comment: "kind:field-label")
        case .materials: String(localized: "Materials", comment: "kind:field-label")
        case .notes: String(localized: "Notes for the editorial team", comment: "kind:field-label")
        case .apps: String(localized: "Apps", comment: "kind:field-label")
        }
    }
}
