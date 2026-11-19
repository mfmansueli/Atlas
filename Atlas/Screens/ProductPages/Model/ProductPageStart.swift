//
//  ProductPageStart.swift
//  Atlas
//

import Foundation

/// What a new page starts with (`appStoreVersionTemplate`,
/// `customProductPageTemplate`, or nothing).
enum ProductPageStart: Codable, Hashable, Sendable {
    /// The default page of the version being prepared: its screenshots,
    /// App Previews and promotional text, in every language.
    case defaultPage
    /// Everything another page has, except its keywords.
    case copy(pageID: ProductPage.ID, name: String)
    /// Nothing: every language shows the default page until it has its own.
    case empty

    /// The New Page sheet's footer: "Starts with version 1.4’s screenshots,
    /// App Previews and promotional text in 12 languages."
    func summary(versionString: String?, languageCount: Int) -> String {
        switch self {
        case .defaultPage:
            let version = versionString.map { String(localized: "version \($0)’s") } ?? String(localized: "the default page’s")
            return String(localized: "Starts with \(version) screenshots, App Previews and promotional text in \(ReviewText.languages(languageCount)).")
        case let .copy(_, name):
            return String(localized: "Starts as a copy of “\(name)”: its screenshots, text and deep link. Keywords are not copied.")
        case .empty:
            return String(localized: "Starts empty. Every language shows the default page’s content until you add your own.")
        }
    }
}
