//
//  ProductPageTreatmentLocalization.swift
//  Atlas
//

import Foundation

/// A treatment's page in one language. Library assets are placed on it as
/// on a version localization, through the placement's
/// `appStoreVersionExperimentTreatmentLocalization` relationship.
struct ProductPageTreatmentLocalization: Hashable, Sendable, Identifiable {
    var id: String
    var locale: String?
    /// The artwork on its page, when the response included it.
    var placements: [AssetLibraryPlacement] = []

    init(id: String, locale: String? = nil, placements: [AssetLibraryPlacement] = []) {
        self.id = id
        self.locale = locale
        self.placements = placements
    }

    init(_ resource: ScreenshotAPIResource<ProductPageTreatmentLocaleAttributes>) {
        self.init(id: resource.id, locale: resource.attributes?.locale)
    }
}
