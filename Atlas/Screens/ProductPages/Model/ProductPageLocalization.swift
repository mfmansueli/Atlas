//
//  ProductPageLocalization.swift
//  Atlas
//

import Foundation

/// One language of a page's version: its promotional text, the keywords
/// that lead to it in that language, and the devices it has its own
/// screenshots or App Previews for. A language the version doesn't have
/// shows the default page's content.
struct ProductPageLocalization: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var locale: String
    var promotionalText: String = ""
    /// The version's keywords chosen for this page, in that language.
    var keywords: [String] = []
    /// `screenshotDisplayType`s of its own screenshot sets.
    var screenshotDisplayTypes: [String] = []
    /// `previewType`s of its own App Preview sets.
    var previewTypes: [String] = []

    var hasOwnText: Bool { !promotionalText.isEmpty }

    var hasOwnScreenshots: Bool { !screenshotDisplayTypes.isEmpty || !previewTypes.isEmpty }

    /// It has something of its own, so it doesn't look like the default page.
    var hasOwnContent: Bool { hasOwnText || hasOwnScreenshots || !keywords.isEmpty }
}
