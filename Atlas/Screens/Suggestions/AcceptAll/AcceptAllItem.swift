//
//  AcceptAllItem.swift
//  Atlas
//

import Foundation

/// One suggestion in the Accept All sheet: which field, who suggested it and
/// why, and what it replaces; a caption also shows its screenshot before
/// and after.
struct AcceptAllItem: Identifiable, Hashable, Sendable {
    /// The suggestion's id.
    let id: String
    /// "Keywords", "Apple Watch · VoiceOver", "Screenshot 2 · caption".
    var title: String
    var source: SuggestionSource
    /// What the field holds now; "" reads "Empty".
    var current: String
    var suggested: String
    var reason: String
    /// A screenshot caption's slot, drawn now and with the suggestion.
    var screenshot: AcceptAllScreenshot?
}
