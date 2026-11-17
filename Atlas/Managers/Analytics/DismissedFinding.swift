//
//  DismissedFinding.swift
//  Atlas
//

import Foundation

/// A finding the person dismissed: kept so it stays away, and so it can be
/// restored. It comes back by itself only if its number changes a lot.
struct DismissedFinding: Hashable, Sendable, Codable, Identifiable {
    /// A number that moved by more than this share counts as "a lot".
    static let returnShare = 0.25

    var finding: AnalyticsFinding
    var date: Date

    var id: String { finding.id }

    /// Whether `current` is the same finding with numbers changed enough
    /// to show it again.
    func hasChangedALot(_ current: AnalyticsFinding) -> Bool {
        guard let old = finding.signal, let new = current.signal, old != 0 else { return false }
        return abs(new - old) / abs(old) > Self.returnShare
    }
}
