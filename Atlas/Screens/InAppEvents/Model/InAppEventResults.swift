//
//  InAppEventResults.swift
//  Atlas
//

import Foundation

/// How an ended event did, from Apple's numbers.
struct InAppEventResults: Hashable, Sendable {
    var pageViews: Int
    /// Opens of the app from the event's card.
    var opens: Int
    var downloads: Int
    /// "From Apple’s App Analytics, Oct 31 – Nov 7."
    var note: String
}
