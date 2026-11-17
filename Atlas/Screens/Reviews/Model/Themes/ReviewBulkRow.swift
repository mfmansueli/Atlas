//
//  ReviewBulkRow.swift
//  Atlas
//

import Foundation

/// One language of Reply to All: its message and the reviews that get it.
struct ReviewBulkRow: Identifiable, Hashable, Sendable {
    /// "de".
    var languageCode: String
    /// "German".
    var languageName: String
    /// The storefront most of its reviews come from, for the flag.
    var territory: String
    var text: String
    var reviewIDs: [AppReview.ID]

    var id: String { languageCode }
}
