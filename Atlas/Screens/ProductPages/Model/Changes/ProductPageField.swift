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
    /// One language's own screenshots on one device (board 52).
    case screenshots
    /// One language's own App Previews on one device.
    case appPreviews

    /// Promotional text's limit, the same as the default page's.
    static let promotionalTextLimit = 170

    /// Set per language.
    var isPerLanguage: Bool { self == .promotionalText || self == .keywords }

    var title: String {
        switch self {
        case .promotionalText: String(localized: "Promotional text")
        case .keywords: String(localized: "Search keywords")
        case .deepLink: String(localized: "Deep link")
        case .name: String(localized: "Name")
        case .visible: String(localized: "Visible on the App Store")
        case .delete: String(localized: "Delete page")
        case .screenshots: String(localized: "Screenshots")
        case .appPreviews: String(localized: "App Previews")
        }
    }
}
