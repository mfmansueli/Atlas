//
//  BreakdownSortLabel.swift
//  Atlas
//

import Foundation

/// What VoiceOver says for a column's header: its name, and when the
/// table is sorted by it, which way ("Impressions, sorted descending").
enum BreakdownSortLabel {
    static func label(title: String, isSorted: Bool, ascending: Bool) -> String {
        guard isSorted else { return title }
        return ascending
            ? String(localized: "\(title), sorted ascending", comment: "kind:accessibility-label · Break It Down column header")
            : String(localized: "\(title), sorted descending", comment: "kind:accessibility-label · Break It Down column header")
    }

    /// What clicking does: the other way round when it's sorted already.
    static func hint(title: String, isSorted: Bool, ascending: Bool) -> String {
        guard isSorted else {
            return String(localized: "Sorts by \(title).", comment: "kind:accessibility-label · Break It Down column header")
        }
        return ascending
            ? String(localized: "Sorts descending.", comment: "kind:accessibility-label · Break It Down column header")
            : String(localized: "Sorts ascending.", comment: "kind:accessibility-label · Break It Down column header")
    }

    /// The arrow beside the sorted column's name.
    static func systemImage(ascending: Bool) -> String {
        ascending ? "chevron.up" : "chevron.down"
    }
}
