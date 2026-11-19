//
//  ProductPageDraft.swift
//  Atlas
//

import Foundation

/// A page made in Atlas, from New Page… or an accepted suggestion. It's one
/// change in Review & Push that creates the page with its version and
/// languages; editing it rewrites that change. Gone once it's pushed.
struct ProductPageDraft: Identifiable, Codable, Hashable, Sendable {
    /// `draft-<uuid>`: never an App Store Connect ID.
    var id: String
    var name: String
    var start: ProductPageStart
    /// Who it's for and what it should do: a note for the assistant, never
    /// sent to Apple.
    var note: String = ""
    /// The languages with their own content; the others show the default
    /// page's.
    var locales: [String]
    var promotionalTexts: [String: String] = [:]
    var keywords: [String: [String]] = [:]
    var deepLink: String = ""
    /// The suggestion it came from.
    var suggestionID: String?
    var source: ChangeSource = .you
    var createdAt: Date = .now

    static let idPrefix = "draft-"

    static func newID() -> String { idPrefix + UUID().uuidString.lowercased() }

    static func isDraftID(_ id: String) -> Bool { id.hasPrefix(idPrefix) }

    /// The page the list and the editor show for it.
    var page: ProductPage {
        let localizations = locales.map { locale in
            ProductPageLocalization(
                id: "\(id).\(locale)", locale: locale,
                promotionalText: promotionalTexts[locale] ?? "", keywords: keywords[locale] ?? []
            )
        }
        let version = ProductPageVersion(id: "", number: 1, state: .prepareForSubmission, deepLink: deepLink, localizations: localizations)
        return ProductPage(id: id, name: name, url: nil, isVisible: false, versions: [version], isDraft: true)
    }
}
