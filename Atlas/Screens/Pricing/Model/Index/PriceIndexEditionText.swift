//
//  PriceIndexEditionText.swift
//  Atlas
//

import Foundation

/// The edition texts of the index snapshots (label, badge, provenance label,
/// newer edition) in the app's language. The JSON keeps English values.
///
/// - The published snapshot's texts follow fixed patterns built from the
///   edition's data year and publication date ("World Bank 2025",
///   "IMF Oct 26"), so a new edition is translated without new strings.
/// - The sample snapshot's fixed texts are keyed by their stable id,
///   `<source>.<field>` (`bigMac.badge`).
///
/// Either way a text is translated only while the JSON says the English
/// Atlas expects, so a snapshot written differently shows as written.
enum PriceIndexEditionText {
    /// The fields of an edition that are shown.
    enum Field: String, CaseIterable {
        case label, badge, provenanceLabel, newerEdition
    }

    /// `value` in the app's language when it's the sample's English for
    /// `id`; otherwise `value` itself.
    static func text(_ value: String, id: String) -> String {
        guard let entry = entries[id], entry.english == value else { return value }
        return entry.localized
    }

    /// `edition` with its shown texts in the app's language, for the
    /// snapshot's `source` key (`bigMac`).
    static func localized(_ edition: PriceIndexEdition, source: String) -> PriceIndexEdition {
        let built = generated(for: edition, source: source)
        func local(_ value: String, _ field: Field) -> String {
            if let entry = built[field], entry.english == value { return entry.localized }
            return text(value, id: id(source, field))
        }
        var edition = edition
        edition.label = local(edition.label, .label)
        edition.badge = local(edition.badge, .badge)
        edition.provenanceLabel = local(edition.provenanceLabel, .provenanceLabel)
        edition.newerEdition = edition.newerEdition.map { text($0, id: id(source, .newerEdition)) }
        return edition
    }

    /// The texts `fetch_price_index.py` writes for an edition with a data
    /// year: the English the JSON should hold, and the app's language.
    static func generated(for edition: PriceIndexEdition, source: String) -> [Field: (english: String, localized: String)] {
        guard let dataYear = edition.dataYear else { return [:] }
        let calendar = Calendar.gmtGregorian
        let month = calendar.component(.month, from: edition.date)
        let publishedYear = String(calendar.component(.year, from: edition.date))
        let year = String(dataYear)
        let shortYear = String(publishedYear.suffix(2))
        let english = englishMonths[month - 1]
        let englishShort = String(english.prefix(3))
        // Editions are days in GMT, so their month is read in GMT too.
        let style = Date.FormatStyle(timeZone: .gmt)
        let wide = edition.date.formatted(style.month(.wide))
        let abbreviated = edition.date.formatted(style.month(.abbreviated))
        switch source {
        case "worldBank":
            return [
                .label: ("\(year) data, published \(publishedYear)", String(localized: "\(year) data, published \(publishedYear)", comment: "kind:description")),
                .badge: ("WB \(year)", String(localized: "WB \(year)", comment: "kind:pill")),
                .provenanceLabel: ("World Bank \(year)", String(localized: "World Bank \(year)", comment: "kind:pill")),
            ]
        case "imf":
            return [
                .label: ("\(english) \(publishedYear) WEO", String(localized: "\(wide) \(publishedYear) WEO", comment: "kind:description")),
                .badge: ("IMF \(englishShort) \(shortYear)", String(localized: "IMF \(abbreviated) \(shortYear)", comment: "kind:pill")),
                .provenanceLabel: ("IMF, \(englishShort) \(publishedYear)", String(localized: "IMF, \(abbreviated) \(publishedYear)", comment: "kind:pill")),
            ]
        case "bigMac":
            return [
                .label: ("\(english) \(publishedYear)", String(localized: "\(wide) \(publishedYear)", comment: "kind:description")),
                .badge: ("Big Mac \(englishShort) \(shortYear)", String(localized: "Big Mac \(abbreviated) \(shortYear)", comment: "kind:pill")),
                .provenanceLabel: ("Big Mac, \(englishShort) \(publishedYear)", String(localized: "Big Mac, \(abbreviated) \(publishedYear)", comment: "kind:pill")),
            ]
        default:
            return [:]
        }
    }

    /// `bigMac.badge`.
    static func id(_ source: String, _ field: Field) -> String {
        "\(source).\(field.rawValue)"
    }

    /// The English the sample snapshot has for `id`, if this table knows it.
    static func english(id: String) -> String? {
        entries[id]?.english
    }

    /// English month names, as the script writes them.
    private static let englishMonths = [
        "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December",
    ]

    /// The sample snapshot's fixed texts.
    private static var entries: [String: (english: String, localized: String)] {
        [
            "bigMac.label": ("January 2026", String(localized: "January 2026", comment: "kind:description")),
            "bigMac.badge": ("Big Mac Jan 26", String(localized: "Big Mac Jan 26", comment: "kind:pill")),
            "bigMac.provenanceLabel": ("Big Mac, Jan 2026", String(localized: "Big Mac, Jan 2026", comment: "kind:pill")),
            "bigMac.newerEdition": ("July 2026", String(localized: "July 2026", comment: "kind:hint")),
            "worldBank.label": ("2024 data, published 2025", String(localized: "2024 data, published 2025", comment: "kind:description")),
            "worldBank.badge": ("WB 2024", String(localized: "WB 2024", comment: "kind:pill")),
            "worldBank.provenanceLabel": ("World Bank 2024", String(localized: "World Bank 2024", comment: "kind:pill")),
            "imf.label": ("April 2026 WEO", String(localized: "April 2026 WEO", comment: "kind:description")),
            "imf.badge": ("IMF Apr 26", String(localized: "IMF Apr 26", comment: "kind:pill")),
            "imf.provenanceLabel": ("IMF, Apr 2026", String(localized: "IMF, Apr 2026", comment: "kind:pill")),
            "imf.newerEdition": ("October 2026", String(localized: "October 2026", comment: "kind:hint")),
        ]
    }
}
