//
//  PushProgressFailureGroup.swift
//  Atlas
//

import Foundation

/// Rows of a push that failed for the same reason, listed once at the top
/// of the progress sheet: "9 failed · Couldn’t place it (…)", then which
/// ones.
struct PushProgressFailureGroup: Hashable, Sendable, Identifiable {
    var reason: String
    var titles: [String]

    var id: String { reason }

    /// "Subtitle · German, Subtitle · French and 2 more"; every title when
    /// there are three or fewer.
    var itemsTitle: String {
        guard titles.count > 3 else { return titles.formatted(.list(type: .and)) }
        return String(localized: "\(titles.prefix(2).joined(separator: ", ")) and \(titles.count - 2) more")
    }
}
