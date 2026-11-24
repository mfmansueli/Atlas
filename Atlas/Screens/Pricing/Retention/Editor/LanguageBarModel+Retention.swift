//
//  LanguageBarModel+Retention.swift
//  Atlas
//

import Foundation

extension LanguageBarModel {
    /// The retention message's language picker: every language, one list
    /// (nothing to review there), each that runs too long saying so; nil
    /// without languages.
    static func retention(languages: [StoreLocale], selectedCode: String, tooLong: Set<String>) -> LanguageBarModel? {
        let entries = languages.map { locale in
            LanguageBarEntry(locale: locale, count: 0, note: tooLong.contains(locale.code) ? String(localized: "Too long") : nil)
        }
        guard let current = languages.first(where: { $0.code == selectedCode }) ?? languages.first else { return nil }
        return LanguageBarModel(entries: entries, current: current, countsSuggestions: false)
    }
}
