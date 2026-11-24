//
//  ProductPagesViewModel+LanguageBar.swift
//  Atlas
//

import Foundation

// A product page's language bar (README-DS §12): one picker, not a chip
// per language. A language with a suggested text has one suggestion to
// review; one that shows the default page's content is listed last.
extension ProductPagesViewModel {
    func languageBarModel(of page: ProductPage) -> LanguageBarModel? {
        let entries = languages(of: page).compactMap { language -> LanguageBarEntry? in
            guard let locale = StoreLocaleCatalog.locale(code: language.code) else { return nil }
            return LanguageBarEntry(locale: locale, count: language.state == .suggested ? 1 : 0, usesPrimary: language.state == .same)
        }
        guard let current = entries.first(where: { $0.locale.code == localeCode })?.locale ?? entries.first?.locale else { return nil }
        return LanguageBarModel(
            entries: entries,
            current: current,
            // Accept All Languages accepts at once; its toast has Undo.
            acceptAllShowsSuggestionsFirst: false,
            reuseGroupTitle: String(localized: "Uses the default page", comment: "kind:section-title")
        )
    }
}
