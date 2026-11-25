//
//  ReviewRiskText.swift
//  Atlas
//

import Foundation

/// One store text as App Review will read it: pushed (live or in the
/// version) or waiting in Review & Push (`isQueued`), in one language.
struct ReviewRiskText: Hashable, Sendable {
    var place: ReviewRiskTextPlace
    /// The listing field, for `.storeListing`.
    var field: ListingField?
    /// The place in the person's words: "Description · German".
    var label: String
    /// The store locale code, e.g. "de-DE".
    var locale: String
    var text: String
    /// Waits in Review & Push, not pushed yet.
    var isQueued = false
    /// A stable key for the risk's ID: "storeListing.description.de-DE".
    var key: String
    /// The in-app text's field, for `.inAppText` (its own rules: a
    /// purchase may be named "7-day Trial").
    var inAppField: InAppTextField?
    /// What the text belongs to beyond the app: the product ID, the event's
    /// or product page's ID, the caption's slot. Nil for the listing.
    var owner: String?
}
