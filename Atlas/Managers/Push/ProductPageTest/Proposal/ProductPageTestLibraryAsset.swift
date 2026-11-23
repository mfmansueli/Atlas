//
//  ProductPageTestLibraryAsset.swift
//  Atlas
//

import Foundation

/// One language's treatment from the app's App Asset Library: the image
/// as `get_page_tests` listed it, so the sheet can show and place it
/// without reading the library again.
struct ProductPageTestLibraryAsset: Codable, Hashable, Sendable, Identifiable {
    var locale: String
    var assetID: String
    /// Its reference name, else its file name.
    var name: String
    var pixelSize: PixelSize

    var id: String { locale }

    var asset: AssetLibraryAsset { AssetLibraryAsset(id: assetID, media: .image) }
}
