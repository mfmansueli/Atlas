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
    /// When a reply the person sent with Send Reply first reached the App
    /// Store: Reply Automatically sends nothing by itself before (board 58,
    /// the write has to be tried by hand first).
    var sentReplyByHandAt: Date?
}
