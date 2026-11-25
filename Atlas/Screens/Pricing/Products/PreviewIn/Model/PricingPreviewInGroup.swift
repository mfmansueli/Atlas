//
//  PricingPreviewInGroup.swift
//  Atlas
//

import Foundation

/// A group of "Preview in"'s menu: the countries with price changes, then
/// every country and region.
struct PricingPreviewInGroup: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case withChanges
        case all
    }

    let kind: Kind
    let countries: [PricingPreviewInCountry]

    var id: Kind { kind }

    var title: String {
        switch kind {
        case .withChanges: String(localized: "With price changes", comment: "kind:section-title")
        case .all: String(localized: "All countries and regions", comment: "kind:section-title")
        }
    }
}
