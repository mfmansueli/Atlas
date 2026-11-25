//
//  PriceSourceText.swift
//  Atlas
//

import Foundation

/// The one way Pricing names where a factor came from (board 76): the
/// source, then its edition. "World Bank · 2025", "IMF · Oct 2026",
/// "Big Mac · Jan 2026", "Region median". The Source column and its help,
/// the price popover's basis line and the inspector's fallback chain all
/// read it, so the same factor is named the same everywhere.
enum PriceSourceText {
    /// The Source column's text. An index value from an older year names
    /// that year ("World Bank · 2024"); a region median, equalized price,
    /// regional tier or excluded country says so.
    static func text(_ provenance: PriceProvenance) -> String {
        switch provenance.kind {
        case let .index(source):
            guard let edition = provenance.edition else { return name(of: source, edition: nil) }
            return text(source, edition: edition, year: provenance.level?.year)
        case .regionMedian:
            return String(localized: "Region median", comment: "kind:label")
        case .equalized, .regionalTier, .excluded:
            return provenance.badge
        }
    }

    /// "World Bank · 2025", "IMF · Oct 2026"; `year` is the value's own
    /// year when it isn't the edition's.
    static func text(_ source: PriceIndexSource, edition: PriceIndexEdition, year: Int? = nil) -> String {
        let name = name(of: source, edition: edition)
        guard let part = editionPart(source, edition: edition, year: year) else { return name }
        return String(localized: "\(name) · \(part)", comment: "kind:label")
    }

    /// The edition alone: "2025" for the World Bank, "Oct 2026" for the IMF
    /// and the Big Mac Index, the import's month for a custom index.
    static func editionPart(_ source: PriceIndexSource, edition: PriceIndexEdition, year: Int? = nil) -> String? {
        if let year, let dataYear = edition.dataYear, year != dataYear { return String(year) }
        if source != .custom, let named = trailing(edition.provenanceLabel, after: source.shortName) { return named }
        switch source {
        case .worldBank:
            return edition.dataYear.map { String($0) } ?? monthYear(edition.date)
        case .imf, .bigMac, .custom:
            return monthYear(edition.date)
        }
    }

    /// "World Bank", "IMF", "Big Mac"; a custom index goes by its badge ("Custom").
    private static func name(of source: PriceIndexSource, edition: PriceIndexEdition?) -> String {
        guard source == .custom else { return source.shortName }
        return edition?.badge ?? source.shortName
    }

    /// What a provenance label says after the source's name: "World Bank
    /// 2025" → "2025", "IMF, Oct 2026" → "Oct 2026". Nil when the label
    /// doesn't start with the name (a snapshot written differently).
    static func trailing(_ label: String, after name: String) -> String? {
        guard label.hasPrefix(name) else { return nil }
        let rest = label.dropFirst(name.count).trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
        return rest.isEmpty ? nil : rest
    }

    /// "Oct 2026". Editions are days in GMT, so their month is read in GMT.
    static func monthYear(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(timeZone: .gmt).month(.abbreviated).year())
    }
}
