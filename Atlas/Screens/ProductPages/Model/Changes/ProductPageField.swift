//
//  ProductPageField.swift
//  Atlas
//

import Foundation

/// What one Review & Push change sets on a custom product page.
enum ProductPageField: String, Codable, Hashable, Sendable, CaseIterable {
    /// One language's promotional text.
    case promotionalText
    /// One language's keywords.
    case keywords
    case deepLink
    case name
    case visible
    /// Deletes the page.
    case delete

    /// Promotional text's limit, the same as the default page's.
    static let promotionalTextLimit = 170

    /// Set per language.
    var isPerLanguage: Bool { self == .promotionalText || self == .keywords }

    var title: String {
        switch self {
        case .promotionalText: String(localized: "Promotional Text")
        case .keywords: String(localized: "Search Keywords")
        case .deepLink: String(localized: "Deep Link")
        case .name: String(localized: "Name")
        case .visible: String(localized: "Visible on the App Store")
        case .delete: String(localized: "Delete Page")
        }
    }
}
