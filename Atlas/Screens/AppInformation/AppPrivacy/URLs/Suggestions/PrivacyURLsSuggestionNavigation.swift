//
//  PrivacyURLsSuggestionNavigation.swift
//  Atlas
//

import Foundation

/// Where App Privacy's suggestion bar arrows go: the previous or next
/// language, in the Privacy URLs table's order, whose User Privacy Choices
/// URL has a suggestion, wrapping around. Before the person has gone to
/// one, the next is the first with a suggestion and the previous the last.
struct PrivacyURLsSuggestionNavigation: Equatable, Sendable {
    /// Every language in the table, in its order.
    var locales: [StoreLocale]
    /// The ones with a suggestion shown.
    var suggested: Set<StoreLocale>
    /// The one the arrows went to last, if any.
    var current: StoreLocale?

    /// The languages with a suggestion, in the table's order.
    var withSuggestions: [StoreLocale] {
        locales.filter(suggested.contains)
    }

    var next: StoreLocale? { neighbor(forward: true) }
    var previous: StoreLocale? { neighbor(forward: false) }

    /// The arrows do something: there's a language with a suggestion that
    /// isn't the one in view.
    var canMove: Bool {
        withSuggestions.contains { $0 != current }
    }

    /// "German, 2 of 3", for the arrows' line; nil while it isn't on one.
    var positionText: String? {
        guard let current, let index = withSuggestions.firstIndex(of: current) else { return nil }
        return String(localized: "\(current.name), \(index + 1) of \(withSuggestions.count)")
    }

    private func neighbor(forward: Bool) -> StoreLocale? {
        let candidates = withSuggestions
        guard let current, let index = locales.firstIndex(of: current) else {
            return forward ? candidates.first : candidates.last
        }
        let after = locales[locales.index(after: index)...]
        let before = locales[..<index]
        let order = forward ? Array(after) + Array(before) : Array(before.reversed()) + Array(after.reversed())
        return order.first(where: suggested.contains)
    }
}
