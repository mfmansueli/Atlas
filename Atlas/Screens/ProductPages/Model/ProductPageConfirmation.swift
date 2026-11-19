//
//  ProductPageConfirmation.swift
//  Atlas
//

import Foundation

/// What asks first (board 55): hiding a page, deleting it, discarding its
/// changes, and moving a keyword another page has.
enum ProductPageConfirmation: Identifiable, Hashable, Sendable {
    case hide(pageID: ProductPage.ID)
    case delete(pageID: ProductPage.ID)
    case discard(pageID: ProductPage.ID)
    /// A keyword leads to one page: choosing it here takes it off `fromPageID`.
    case moveKeyword(String, locale: String, fromPageID: ProductPage.ID, fromName: String)

    var id: String {
        switch self {
        case let .hide(pageID): "hide.\(pageID)"
        case let .delete(pageID): "delete.\(pageID)"
        case let .discard(pageID): "discard.\(pageID)"
        case let .moveKeyword(keyword, locale, from, _): "move.\(locale).\(keyword).\(from)"
        }
    }
}
