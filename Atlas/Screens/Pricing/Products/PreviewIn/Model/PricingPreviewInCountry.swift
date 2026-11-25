//
//  PricingPreviewInCountry.swift
//  Atlas
//

import Foundation

/// A country or region in "Preview in"'s menu, and whether any product's
/// price changes there (an open suggestion or a change not pushed yet).
struct PricingPreviewInCountry: Identifiable, Hashable, Sendable {
    var territory: Territory
    var hasChange: Bool

    var id: String { territory.id }

    /// Find a country or currency: part of the name ("braz"), either ISO
    /// code ("BR", "bra"), or the currency's code or name ("BRL", "real").
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        if territory.name.localizedStandardContains(query) { return true }
        if [territory.alpha2, territory.id].contains(where: { $0.caseInsensitiveCompare(query) == .orderedSame }) { return true }
        if territory.currencyCode.localizedStandardContains(query) { return true }
        return Self.currencyNames(territory.currencyCode).contains { $0.localizedStandardContains(query) }
    }

    /// "Brazilian Real", in English and in the person's language.
    private static func currencyNames(_ code: String) -> [String] {
        [Locale(identifier: "en_US"), Locale.current].compactMap { $0.localizedString(forCurrencyCode: code) }
    }
}
