//
//  InAppEventsViewModel+LanguageBar.swift
//  Atlas
//

import Foundation

// The event's language bar (README-DS §12): one picker, not a chip per
// language. A suggested language or a revision is one suggestion to review;
// a language not written yet shows the primary one's texts and is listed
// last; text not pushed says so in its row.
extension InAppEventsViewModel {
    /// The bar over `event`'s texts; nil before its languages are known.
    func languageBarModel(of event: InAppEvent) -> LanguageBarModel? {
        let languages = languages(of: event)
        let entries = languages.compactMap { language -> LanguageBarEntry? in
            guard let locale = language.locale else { return nil }
            return LanguageBarEntry(
                locale: locale,
                count: language.state == .suggested || language.state == .revision ? 1 : 0,
                usesPrimary: language.state == .missing,
                note: language.state == .notPushed ? String(localized: "Not pushed") : nil
            )
        }
        guard let current = entries.first(where: { $0.locale.code == localeCode })?.locale ?? entries.first?.locale else { return nil }
        let primary = event.primaryLocale.map(InAppEventChangeBuilder.localeName) ?? String(localized: "the primary language")
        return LanguageBarModel(
            entries: entries,
            current: current,
            // Accept All Languages accepts at once; its toast has Undo.
            acceptAllShowsSuggestionsFirst: false,
            reuseGroupTitle: String(localized: "Uses \(primary)")
        )
    }
}
