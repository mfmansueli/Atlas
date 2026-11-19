//
//  ProductPageDefaultLanguage.swift
//  Atlas
//

import Foundation

/// One language of the default page: what a custom page shows when it has
/// nothing of its own there, and the keywords a page can choose from.
struct ProductPageDefaultLanguage: Identifiable, Codable, Hashable, Sendable {
    /// The version localization's ID (`appStoreVersionLocalizations`), for
    /// its screenshots.
    var id: String
    var locale: String
    var promotionalText: String = ""
    /// The keywords of the last approved version in this language, in its
    /// order: the only words a page can choose.
    var approvedKeywords: [String] = []
}
