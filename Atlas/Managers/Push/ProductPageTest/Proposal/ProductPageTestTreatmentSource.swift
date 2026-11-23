//
//  ProductPageTestTreatmentSource.swift
//  Atlas
//

import Foundation

/// What a proposed test shows as its treatment: the Autopilot run's
/// variant (`propose_artwork_variant`), rendered and checked in every
/// language, or images already in the app's App Asset Library, one per
/// language.
enum ProductPageTestTreatmentSource: Codable, Hashable, Sendable {
    /// The variant, with the one idea it changes.
    case variant(change: String)
    case library([ProductPageTestLibraryAsset])

    /// "variant", "library": the MCP value.
    var toolValue: String {
        switch self {
        case .variant: "variant"
        case .library: "library"
        }
    }

    /// The library assets, by locale; empty for the variant.
    var libraryAssets: [ProductPageTestLibraryAsset] {
        if case let .library(assets) = self { return assets }
        return []
    }
}
