//
//  EngagementArchive.swift
//  Atlas
//

import Foundation

/// One app's store-page facts as kept on this Mac, and which of Apple's
/// files they came from. Apple reprocesses days: a later file replaces an
/// earlier one's numbers for the same day, never adds to them.
struct EngagementArchive: Hashable, Sendable, Codable {
    /// Days kept: enough for 90 days against the 90 before.
    static let keptDays = 200

    /// By territory, source and device (the Standard reports).
    var facts: [EngagementFact] = []
    /// By product page, source, referrer and campaign (the Detailed
    /// reports).
    var pageFacts: [EngagementFact] = []
    /// "kind|detailed|day" → the processing day its numbers came from.
    var processed: [String: Int] = [:]
    /// Instances already read, so they aren't downloaded again.
    var instanceIDs: Set<String> = []

    var isEmpty: Bool { facts.isEmpty && pageFacts.isEmpty }

    /// The newest day with any impressions or page views.
    var lastDay: AnalyticsDay? { facts.map(\.day).max() }
    var firstDay: AnalyticsDay? { facts.map(\.day).min() }

    /// Takes in downloaded instances, oldest processing first.
    mutating func apply(_ batches: [EngagementBatch]) {
        for batch in batches.sorted(by: { $0.processing < $1.processing }) {
            apply(batch)
        }
        guard let last = lastDay else { return }
        let cutoff = last.adding(-Self.keptDays)
        facts.removeAll { $0.day < cutoff }
        pageFacts.removeAll { $0.day < cutoff }
    }

    private mutating func apply(_ batch: EngagementBatch) {
        instanceIDs.insert(batch.instanceID)
        let incoming = Dictionary(grouping: batch.facts, by: \.day)
        var replaced: Set<AnalyticsDay> = []
        for day in incoming.keys {
            let key = "\(batch.kind.rawValue)|\(batch.isDetailed)|\(day.number)"
            if let known = processed[key], known > batch.processing.number { continue }
            processed[key] = batch.processing.number
            replaced.insert(day)
        }
        guard !replaced.isEmpty else { return }
        let fresh = replaced.flatMap { incoming[$0] ?? [] }
        if batch.isDetailed {
            // The page, and where people came from; the Standard report
            // has territories and devices.
            let byPage = fresh.map { fact in
                var fact = fact
                fact.territory = ""
                fact.device = ""
                return fact
            }
            pageFacts = Self.replacing(batch.kind, on: replaced, in: pageFacts, with: byPage)
        } else {
            facts = Self.replacing(batch.kind, on: replaced, in: facts, with: fresh)
        }
    }

    /// `existing` with `kind`'s counts on `days` cleared, then `fresh` added.
    private static func replacing(
        _ kind: EngagementReportKind, on days: Set<AnalyticsDay>, in existing: [EngagementFact], with fresh: [EngagementFact]
    ) -> [EngagementFact] {
        let cleared = existing.map { fact in
            guard days.contains(fact.day) else { return fact }
            var fact = fact
            switch kind {
            case .engagement:
                fact.impressions = 0
                fact.pageViews = 0
            case .downloads:
                fact.downloads = 0
                fact.redownloads = 0
            }
            return fact
        }
        return EngagementFact.merged(cleared + fresh).filter { $0.impressions + $0.pageViews + $0.downloads + $0.redownloads > 0 }
    }
}
