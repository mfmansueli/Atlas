//
//  AnalyticsFinding.swift
//  Atlas
//

import Foundation

/// Something the numbers say is worth changing: what was seen, the numbers
/// behind it, how sure it is, and one place to act.
struct AnalyticsFinding: Hashable, Sendable, Identifiable, Codable {
    /// Stable across downloads, so a dismissed finding stays dismissed:
    /// "territory.downloads.DE".
    var id: String
    var source: FindingSource
    var title: String
    var why: String
    var numbers: [FindingNumber] = []
    /// "Sure", "Fairly sure" or "Rough".
    var sureness: String
    /// The counts and range behind `sureness`.
    var surenessDetail: String
    var action: FindingAction
    var secondAction: FindingAction?
    /// When it was first seen.
    var date: Date = .now
    /// The number it rests on, to tell when a dismissed one "changed a lot".
    var signal: Double?
    /// For an assistant's finding: what it read for it (tools, reports,
    /// files), shown under the finding.
    var read: [String]?

    var area: AnalyticsArea { action.area }
}
