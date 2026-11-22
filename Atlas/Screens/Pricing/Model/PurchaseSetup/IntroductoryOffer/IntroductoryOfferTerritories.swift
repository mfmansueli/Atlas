//
//  IntroductoryOfferTerritories.swift
//  Atlas
//

import Foundation

/// Where an introductory offer runs: every country or region the
/// subscription is sold in (read when the push sends it), or the chosen
/// ones (alpha-3).
enum IntroductoryOfferTerritories: Hashable, Sendable {
    case everywhere
    case chosen([String])

    /// The chosen territories; nil for everywhere.
    var chosenIDs: [String]? {
        if case let .chosen(ids) = self { return ids }
        return nil
    }

    /// "every country or region it’s sold in", "the United States and Brazil".
    var title: String {
        switch self {
        case .everywhere:
            return String(localized: "every country or region it’s sold in")
        case let .chosen(ids):
            let names = ids.map { TerritoryCatalog.standard.territory(alpha3: $0)?.name ?? $0 }
            if names.count > 4 { return String(localized: "\(names.count) countries or regions") }
            return names.formatted(.list(type: .and))
        }
    }
}
