//
//  ProductPageTestLocale.swift
//  Atlas
//

import Foundation

/// One language of a test: the variant rendered for it (the treatment)
/// and, for the export, the image the page has now (the control). A
/// treatment already in the app's App Asset Library (`libraryAsset`, from
/// an assistant's proposal) is placed as it is, without a file to upload.
struct ProductPageTestLocale: Hashable, Sendable, Identifiable {
    /// App Store Connect's locale code, e.g. `de-DE`.
    var locale: String
    /// The variant's file; nil when the treatment is a library asset.
    var treatmentFile: URL?
    var treatmentPixelSize: PixelSize
    /// The current header or search image in this language; nil when
    /// there's none to export.
    var controlFile: URL?
    /// The treatment when it's in the app's library already.
    var libraryAsset: AssetLibraryAsset?

    var id: String { locale }
}
