//
//  PriceIndexEdition.swift
//  Atlas
//

import Foundation

/// Which edition of an index the snapshot holds, and how the app labels it.
struct PriceIndexEdition: Hashable, Sendable {
    /// The index picker's edition line, e.g. "July 2026" or
    /// "2025 data, published 2026".
    var label: String
    /// The provenance badge in table rows, e.g. "Big Mac Jul 26".
    var badge: String
    /// The source in breakdown lines, e.g. "× 0.75 (Big Mac, Jul 2026)".
    var provenanceLabel: String
    /// When the edition was published.
    var date: Date
    /// A newer edition the publisher has out, e.g. "January 2027".
    var newerEdition: String?
    /// The year the figures describe, e.g. 2025 for World Bank data
    /// published in 2026. Nil for the sample snapshot and custom imports.
    var dataYear: Int?
    /// When the snapshot script downloaded the edition.
    var fetchDate: Date?
    /// The publisher's page for this series.
    var url: URL?

    /// "Older than a year" in the index picker.
    func isStale(asOf now: Date) -> Bool {
        isOlder(thanMonths: 12, asOf: now)
    }

    /// True once `months` have passed since publication.
    func isOlder(thanMonths months: Int, asOf now: Date) -> Bool {
        guard let limit = Calendar.gmtGregorian.date(byAdding: .month, value: months, to: date) else { return false }
        return limit < now
    }

    /// "July 2026 available", or nil.
    var newerEditionLabel: String? {
        newerEdition.map { String(localized: "\($0) available", comment: "kind:hint") }
    }
}
