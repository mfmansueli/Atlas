//
//  ReportsArchive.swift
//  Atlas
//

import Foundation

/// One app's newer reports as kept on this Mac: their facts, which files
/// they came from, and where each report stands. As with the funnel's
/// reports, a later file replaces an earlier one's numbers for the same
/// day, never adds to them.
struct ReportsArchive: Hashable, Sendable, Codable {
    /// Days kept: enough for 90 days against the 90 before.
    static let keptDays = 200

    /// By `AppleReportKind.rawValue`.
    var facts: [String: [ReportFact]] = [:]
    /// "kind|day" → the processing day its numbers came from.
    var processed: [String: Int] = [:]
    var instanceIDs: Set<String> = []
    /// By `AppleReportKind.rawValue`.
    var progress: [String: ReportProgress] = [:]
    /// When Atlas first looked for these reports for this app: for an app
    /// asked before, the day "asked" means for them.
    var firstChecked: Date?

    var isEmpty: Bool { facts.values.allSatisfy(\.isEmpty) }

    func records(_ kind: AppleReportKind) -> [ReportRecord] {
        (facts[kind.rawValue] ?? []).map { ReportRecord(kind: kind, fact: $0) }
    }

    func progress(_ kind: AppleReportKind) -> ReportProgress {
        progress[kind.rawValue] ?? ReportProgress()
    }

    func hasRows(_ kind: AppleReportKind) -> Bool {
        !(facts[kind.rawValue] ?? []).isEmpty
    }

    /// The newest day of `kind`'s rows.
    func lastDay(_ kind: AppleReportKind) -> AnalyticsDay? {
        facts[kind.rawValue]?.last?.day
    }

    /// Reports with nothing read yet: Apple is still making them.
    var pending: [AppleReportKind] {
        AppleReportKind.allCases.filter { progress($0).state == .asked }
    }

    /// Takes in a check: what Apple lists, then the instances, oldest
    /// processing first.
    mutating func apply(_ download: ReportsDownload, now: Date) {
        if firstChecked == nil { firstChecked = now }
        for (kind, count) in download.listed {
            var entry = progress(kind)
            entry.isListed = true
            entry.instances = max(entry.instances, count)
            progress[kind.rawValue] = entry
        }
        for batch in download.batches.sorted(by: { $0.processing < $1.processing }) {
            apply(batch)
        }
        for kind in AppleReportKind.allCases {
            guard var list = facts[kind.rawValue], let last = list.last?.day else { continue }
            let cutoff = last.adding(-Self.keptDays)
            list.removeAll { $0.day < cutoff }
            facts[kind.rawValue] = list
            var entry = progress(kind)
            entry.lastDay = last
            progress[kind.rawValue] = entry
        }
    }

    private mutating func apply(_ batch: ReportBatch) {
        instanceIDs.insert(batch.instanceID)
        var entry = progress(batch.kind)
        entry.isListed = true
        entry.rows += batch.facts.count
        progress[batch.kind.rawValue] = entry
        let incoming = Dictionary(grouping: batch.facts, by: \.day)
        var replaced: Set<AnalyticsDay> = []
        for day in incoming.keys {
            let key = "\(batch.kind.rawValue)|\(day.number)"
            if let known = processed[key], known > batch.processing.number { continue }
            processed[key] = batch.processing.number
            replaced.insert(day)
        }
        guard !replaced.isEmpty else { return }
        let kept = (facts[batch.kind.rawValue] ?? []).filter { !replaced.contains($0.day) }
        let fresh = replaced.flatMap { incoming[$0] ?? [] }
        facts[batch.kind.rawValue] = ReportFact.merged(kept + fresh)
    }
}
