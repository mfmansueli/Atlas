//
//  ProductPageDefault.swift
//  Atlas
//

import Foundation

/// The app's default product page: the version every custom page starts
/// from, and the last version Apple approved, whose keywords pages choose.
struct ProductPageDefault: Codable, Hashable, Sendable {
    /// The App Store version a new page starts from (`appStoreVersionTemplate`).
    var versionID: String?
    /// "1.4".
    var versionString: String?
    /// "1.3": the last approved version; nil before the first approval.
    var approvedVersionString: String?
    var languages: [ProductPageDefaultLanguage] = []

    func language(_ locale: String) -> ProductPageDefaultLanguage? {
        languages.first { $0.locale == locale }
    }

    /// Pages can choose keywords only once a version is approved.
    var hasApprovedVersion: Bool { approvedVersionString != nil }

    var locales: [String] { languages.map(\.locale) }
}
