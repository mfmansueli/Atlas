//
//  AnalyticsFindingsState.swift
//  Atlas
//

import Foundation

/// One app's findings as the person left them.
struct AnalyticsFindingsState: Hashable, Sendable, Codable {
    /// Atlas's own, from the last time they were worked out.
    var builtIn: [AnalyticsFinding] = []
    /// Added by assistants over MCP.
    var fromAssistants: [AnalyticsFinding] = []
    var dismissed: [DismissedFinding] = []
    /// Findings the person has looked at; the rest count as new.
    var seen: Set<String> = []
    /// When each finding first showed, so "New" and the list's order hold
    /// across downloads.
    var firstSeen: [String: Date] = [:]
    /// When the person followed a finding to its section; a change pushed
    /// there afterwards is its result.
    var actedOn: [String: Date] = [:]

    /// Everything not dismissed, assistants' first, then newest first.
    var open: [AnalyticsFinding] {
        let hidden = Set(dismissed.map(\.id))
        return (fromAssistants + builtIn).filter { !hidden.contains($0.id) }
    }

    var newCount: Int {
        open.count { !seen.contains($0.id) }
    }

    func isNew(_ finding: AnalyticsFinding) -> Bool {
        !seen.contains(finding.id)
    }

    /// Replaces the built-in findings with freshly computed ones, keeping
    /// each one's first date and letting a dismissed one back in when its
    /// numbers changed a lot.
    mutating func update(builtIn fresh: [AnalyticsFinding]) {
        builtIn = fresh.map { finding in
            var finding = finding
            if let first = firstSeen[finding.id] {
                finding.date = first
            } else {
                firstSeen[finding.id] = finding.date
            }
            return finding
        }
        dismissed.removeAll { old in
            guard let current = fresh.first(where: { $0.id == old.id }) else { return false }
            let returns = old.hasChangedALot(current)
            if returns { seen.remove(old.id) }
            return returns
        }
        let alive = Set(fresh.map(\.id)).union(fromAssistants.map(\.id)).union(dismissed.map(\.id))
        seen = seen.intersection(alive)
    }
}
