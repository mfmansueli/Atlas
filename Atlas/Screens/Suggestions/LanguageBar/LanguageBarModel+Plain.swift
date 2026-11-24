//
//  LanguageBarModel+Plain.swift
//  Atlas
//

import Foundation

extension LanguageBarModel {
    /// A language switch with nothing to review (the Autopilot studio, its
    /// review, a recording, an event's artwork viewer): the languages of
    /// `codes` the catalog knows, in order, one list; nil when there are
    /// fewer than two, so there's nothing to switch.
    static func plain(codes: [String], current: String) -> LanguageBarModel? {
        let locales = codes.compactMap { StoreLocaleCatalog.locale(code: $0) }
        guard locales.count > 1, let shown = locales.first(where: { $0.code == current }) ?? locales.first else { return nil }
        return LanguageBarModel(entries: locales.map { LanguageBarEntry(locale: $0, count: 0) }, current: shown, countsSuggestions: false)
    }
}
