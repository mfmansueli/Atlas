//
//  LanguageBarModel+StorePreview.swift
//  Atlas
//

import Foundation

extension LanguageBarModel {
    /// The picker over Overview's App Store preview: the page's languages,
    /// the primary one first, each with the Store Page suggestions it has
    /// to review (`counts`, by locale code). It only changes the preview:
    /// its menu has no Accept All Languages.
    static func storePreview(locales: [StoreLocale], primary: StoreLocale, current: StoreLocale, counts: [String: Int]) -> LanguageBarModel {
        var ordered = [primary] + locales.filter { $0 != primary }
        if !ordered.contains(current) { ordered.append(current) }
        return LanguageBarModel(
            entries: ordered.map { LanguageBarEntry(locale: $0, count: counts[$0.code] ?? 0) },
            current: current
        )
    }
}
