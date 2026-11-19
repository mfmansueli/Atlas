//
//  ProductPageVersion.swift
//  Atlas
//

import Foundation

/// One version of a custom product page: what App Review approves. A page
/// edited after approval gets a new version, shown beside the approved one
/// until Apple approves it.
struct ProductPageVersion: Identifiable, Codable, Hashable, Sendable {
    var id: String
    /// 1, 2, …: App Store Connect numbers them.
    var number: Int
    var state: ProductPageState
    var deepLink: String = ""
    var localizations: [ProductPageLocalization] = []

    func localization(_ locale: String) -> ProductPageLocalization? {
        localizations.first { $0.locale == locale }
    }

    var locales: [String] { localizations.map(\.locale) }

    /// Every keyword chosen for the page, across its languages.
    var keywordCount: Int { localizations.reduce(0) { $0 + $1.keywords.count } }
}
