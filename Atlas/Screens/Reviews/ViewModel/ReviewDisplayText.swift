//
//  ReviewDisplayText.swift
//  Atlas
//

import Foundation

/// A review's title and text as its card shows them: translated or as
/// written, with the line that says which and the button to switch.
struct ReviewDisplayText: Hashable, Sendable {
    var title: String
    var body: String
    /// "Translated from German" or "Original, in German"; nil for a review
    /// already in the app's language.
    var note: String?
    /// "Show Original" or "Show Translation"; nil when there's nothing to
    /// switch to.
    var toggleTitle: String?
    var isTranslated: Bool
    /// The text runs right to left (Arabic or Hebrew, as written).
    var isRightToLeft: Bool
}
