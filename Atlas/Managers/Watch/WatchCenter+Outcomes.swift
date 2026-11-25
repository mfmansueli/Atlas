//
//  WatchCenter+Outcomes.swift
//  Atlas
//

import Foundation

// What became of each run's findings, and what that does to their kinds.
extension WatchCenter {
    /// Settles the runs that ended: once every finding a run took has an
    /// outcome (or a week went by), each kind's batch goes into its backoff
    /// and the findings' records take the person's answer. A run that
    /// didn't finish teaches nothing: its findings may go again.
    /// `found`: what this check found, per app.
    func settle(_ found: [StoreApp.ID: [WatchSignal]], suggestions: FieldSuggestionStore?) {
        let date = now()
        for (appID, signals) in found {
            let current = Set(signals.map(\.identity))
            let archive = archive(for: appID)
            for entry in archive.history where !entry.isSettled && !entry.result.isWorking {
                guard entry.result == .finished else {
                    update(appID) { Self.release(entry, in: &$0) }
                    continue
                }
                var outcomes: [(WatchSignal, WatchSignalOutcome)] = []
                for signal in entry.signals {
                    let evidence = suggestions.map { Self.evidence(for: signal, runID: entry.id, in: $0) } ?? WatchOutcomes.Suggestions()
                    guard let outcome = WatchOutcomes.outcome(
                        of: signal, record: archive.records[signal.identity], isStillFound: current.contains(signal.identity),
                        suggestions: evidence, sentAt: entry.startedAt, now: date
                    ) else { break }
                    outcomes.append((signal, outcome))
                }
                guard outcomes.count == entry.signals.count else { continue }
                update(appID) { Self.apply(outcomes, of: entry, in: &$0, now: date) }
            }
        }
    }

    /// The batch per kind into its backoff; each finding still waiting on
    /// this run takes its outcome.
    private static func apply(_ outcomes: [(WatchSignal, WatchSignalOutcome)], of entry: WatchHistoryEntry, in archive: inout WatchArchive, now: Date) {
        for kind in WatchSignalKind.allCases {
            let list = outcomes.filter { $0.0.kind == kind }.map(\.1)
            guard !list.isEmpty else { continue }
            archive.updateStats(for: kind) { WatchBackoff.record(list, runID: entry.id, in: &$0) }
        }
        for (signal, outcome) in outcomes {
            guard case let .sent(runID, _)? = archive.records[signal.identity]?.state, runID == entry.id else { continue }
            switch outcome {
            case .accepted, .edited: WatchLedger.decide(signal.identity, .accepted(date: now), in: &archive)
            case .dismissed: WatchLedger.decide(signal.identity, .dismissed(date: now), in: &archive)
            case .ignored: break
            }
        }
        archive.updateEntry(entry.id) { $0.isSettled = true }
    }

    /// A run that stopped, failed or ended with Atlas: its findings are new
    /// again.
    private static func release(_ entry: WatchHistoryEntry, in archive: inout WatchArchive) {
        for signal in entry.signals {
            guard case let .sent(runID, _)? = archive.records[signal.identity]?.state, runID == entry.id else { continue }
            WatchLedger.decide(signal.identity, .new, in: &archive)
        }
        archive.updateEntry(entry.id) { $0.isSettled = true }
    }

    /// The suggestions run `runID` tagged for `signal`, as the person left
    /// them: What's New, for now (the other kinds' proposals are counted by
    /// what the person decides on the finding itself, or by its fix).
    static func evidence(for signal: WatchSignal, runID: UUID, in store: FieldSuggestionStore) -> WatchOutcomes.Suggestions {
        guard signal.kind == .whatsNewMissing else { return WatchOutcomes.Suggestions() }
        var evidence = WatchOutcomes.Suggestions()
        let tagged = store.all(for: signal.appID, area: .storePage).filter {
            $0.origin == .watch(runID: runID) && $0.target.field == ListingField.whatsNew.rawValue
        }
        for suggestion in tagged {
            if store.isAccepted(suggestion) {
                let provenance = store.provenance(for: suggestion.target, appID: suggestion.appID)
                if provenance?.suggestionID == suggestion.id, provenance?.isForEditing == true {
                    evidence.edited += 1
                } else {
                    evidence.accepted += 1
                }
            } else if store.isDismissed(suggestion) {
                evidence.dismissed += 1
            } else {
                evidence.open += 1
            }
        }
        return evidence
    }
}
