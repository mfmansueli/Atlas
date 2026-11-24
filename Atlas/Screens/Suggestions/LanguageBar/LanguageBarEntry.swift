//
//  LanguageBarEntry.swift
//  Atlas
//

import Foundation

/// One language in the language bar's menu.
struct LanguageBarEntry: Identifiable, Hashable, Sendable {
    let locale: StoreLocale
    /// Suggestions to review in it.
    var count: Int
    /// How many Suggest Everything still owes it.
    var comingCount = 0
    /// The app supports it and the App Store doesn't have it yet.
    var isNewPage = false
    /// It shows the primary language's content (screenshots, an event's
    /// texts, the default page): with nothing to review, the menu lists it
    /// under the model's `reuseGroupTitle`.
    var usesPrimary = false
    /// What its row says in place of the ✓ ("Not pushed", "Too long").
    var note: String?

    var id: String { locale.code }

    /// "German, 5 suggestions to review, not on the App Store yet".
    var accessibilityText: String { accessibilityText(countsSuggestions: true) }

    /// "German, too long" where the switch doesn't count suggestions.
    func accessibilityText(countsSuggestions: Bool) -> String {
        var parts = [locale.name]
        switch (countsSuggestions, count) {
        case (false, _): break
        case (true, 0): parts.append(String(localized: "nothing to review"))
        case (true, 1): parts.append(String(localized: "1 suggestion to review"))
        default: parts.append(String(localized: "\(count) suggestions to review"))
        }
        if comingCount > 0 { parts.append(String(localized: "\(comingCount) coming")) }
        if isNewPage { parts.append(String(localized: "not on the App Store yet")) }
        if let note { parts.append(note) }
        return parts.joined(separator: ", ")
    }
}
