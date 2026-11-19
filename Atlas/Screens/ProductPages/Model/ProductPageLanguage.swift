//
//  ProductPageLanguage.swift
//  Atlas
//

import Foundation

/// A chip on the editor's language bar.
struct ProductPageLanguage: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable {
        /// An assistant's text waits to be accepted.
        case suggested
        /// Its own text, keywords or screenshots.
        case own
        /// Shows the default page's content.
        case same
    }

    var code: String
    var state: State

    var id: String { code }

    var name: String { ProductPageChangeBuilder.localeName(code) }

    var isRightToLeft: Bool { StoreLocaleCatalog.locale(code: code)?.isRTL ?? false }

    /// "German, 1 suggestion", "Arabic, has its own text", "French, same as
    /// the default page".
    var spokenLabel: String {
        switch state {
        case .suggested: String(localized: "\(name), 1 suggestion")
        case .own: String(localized: "\(name), has its own text")
        case .same: String(localized: "\(name), same as the default page")
        }
    }
}
