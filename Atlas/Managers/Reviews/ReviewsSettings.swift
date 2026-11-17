//
//  ReviewsSettings.swift
//  Atlas
//

import Foundation

/// Reviews' settings, the same for every app.
struct ReviewsSettings: Hashable, Codable, Sendable {
    /// "Translate to English": reviews show translated, with Show Original
    /// on each.
    var translates = true
}
