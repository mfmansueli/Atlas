//
//  ProductPageBrief.swift
//  Atlas
//

import Foundation

/// What an accepted suggestion asks of its page: who it's for and the
/// screenshots it should lead with, which Make Screenshots for This Page
/// lays out. Kept on this Mac by the page's name, so it's still in the
/// editor once the draft is pushed.
struct ProductPageBrief: Codable, Hashable, Sendable {
    /// Who the page is for, from the suggestion.
    var audience: String
    /// The screenshots in order, e.g. "Today (“A new phrase every
    /// morning”), then Widgets".
    var screens: String
    /// Who suggested it, e.g. "Claude Code".
    var source: String

    /// The key a page's brief is kept under: its name, case and spaces at
    /// the ends ignored.
    static func key(_ pageName: String) -> String {
        pageName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
