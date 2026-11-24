//
//  PriceIndexEditionText.swift
//  Atlas
//

import Foundation

/// The edition texts of `PriceIndexSnapshot.json` (label, badge,
/// provenance label, newer edition) in the app's language. The JSON keeps
/// its English values; each is keyed by its stable id, `<source>.<field>`
/// (`bigMac.badge`), and translated only while the JSON still says the
/// English this table knows, so a newer snapshot's texts show as written
/// until the table catches up.
enum PriceIndexEditionText {
    /// The fields of an edition that are shown.
    enum Field: String, CaseIterable {
        case label, badge, provenanceLabel, newerEdition
    }

    /// `value` in the app's language when it's the bundled English for `id`;
    /// otherwise `value` itself.
    static func text(_ value: String, id: String) -> String {
        guard let entry = entries[id], entry.english == value else { return value }
        return entry.localized
    }

    /// `edition` with its shown texts in the app's language, for the
    /// bundled snapshot's `source` key (`bigMac`).
    static func localized(_ edition: PriceIndexEdition, source: String) -> PriceIndexEdition {
        var edition = edition
        edition.label = text(edition.label, id: id(source, .label))
        edition.badge = text(edition.badge, id: id(source, .badge))
        edition.provenanceLabel = text(edition.provenanceLabel, id: id(source, .provenanceLabel))
        edition.newerEdition = edition.newerEdition.map { text($0, id: id(source, .newerEdition)) }
        return edition
    }

    /// `bigMac.badge`.
    static func id(_ source: String, _ field: Field) -> String {
        "\(source).\(field.rawValue)"
    }

    /// The English the bundled snapshot has for `id`, if this table knows it.
    static func english(id: String) -> String? {
        entries[id]?.english
    }

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
