//
//  WatchLedger.swift
//  Atlas
//

import Foundation

/// Look for Improvements' memory of each finding (`WatchArchive.records`),
/// as pure functions: what a check saw, what each finding's state lets
/// through, and what a run took. The same finding (same identity, number
/// within a quarter) is never sent twice while it waits for the person;
/// an accepted or dismissed one comes back only once its number moves by
/// more than a quarter, a snoozed one after Not Now's week.
enum WatchLedger {
    /// Not Now.
    static let snoozeTime: TimeInterval = 7 * 24 * 3600
    /// A finding sent this long ago with nothing decided may go again.
    static let resendAfter: TimeInterval = 7 * 24 * 3600
    /// Records not seen for this long are forgotten.
    static let forgetAfter: TimeInterval = 30 * 24 * 3600

    /// Notes what a check found: each finding's record is seen now; one
    /// accepted or dismissed comes back as new when its number moved a lot,
    /// a snoozed one once its week is over. Records gone for a month go,
    /// unless a run still waits on them.
    static func observe(_ signals: [WatchSignal], in archive: inout WatchArchive, now: Date) {
        for signal in signals {
            guard var record = archive.records[signal.identity] else {
                archive.records[signal.identity] = WatchRecord(signal: signal, firstSeen: now, lastSeen: now)
                continue
            }
            switch record.state {
            case .accepted, .dismissed:
                if signal.hasMovedALot(from: record.decidedValue ?? record.signal.value) {
                    record.state = .new
                    record.decidedValue = nil
                }
            case let .snoozed(until) where until <= now:
                record.state = .new
            case .new, .sent, .snoozed:
                break
            }
            record.signal = signal
            record.lastSeen = now
            archive.records[signal.identity] = record
        }
        let waitedOn = Set(archive.history.filter { !$0.isSettled }.flatMap(\.signals).map(\.identity))
        archive.records = archive.records.filter { now.timeIntervalSince($1.lastSeen) < forgetAfter || waitedOn.contains($0) }
    }

    /// What each finding gets this time. Call after `observe`.
    static func decide(_ signals: [WatchSignal], in archive: WatchArchive, dedupe: WatchDedupe, now: Date) -> [WatchDecision] {
        signals.map { WatchDecision(signal: $0, verdict: verdict(for: $0, in: archive, dedupe: dedupe, now: now)) }
    }

    static func verdict(for signal: WatchSignal, in archive: WatchArchive, dedupe: WatchDedupe, now: Date) -> WatchDecision.Verdict {
        let stats = archive.stats(for: signal.kind)
        if stats.isSilenced { return .skip(.silenced) }
        if let record = archive.records[signal.identity] {
            switch record.state {
            case .accepted: return .skip(.accepted)
            case .dismissed: return .skip(.dismissed)
            case let .snoozed(until) where until > now: return .skip(.snoozed(until: until))
            case let .sent(_, date) where now.timeIntervalSince(date) < resendAfter: return .skip(.alreadySent)
            case .new, .sent, .snoozed: break
            }
        }
        if let reason = dedupe.reason(for: signal) { return .skip(reason) }
        if signal.kind.isLocalOnly { return .localOnly }
        if stats.isPaused { return .skip(.paused) }
        if let next = WatchBackoff.nextDate(for: signal.kind, stats: stats), next > now { return .skip(.notDue(until: next)) }
        return .send
    }

    /// Run `runID` took `signals`: they wait for the person, and their kinds
    /// count as brought up now.
    static func markSent(_ signals: [WatchSignal], runID: UUID, in archive: inout WatchArchive, now: Date) {
        for signal in signals {
            var record = archive.records[signal.identity] ?? WatchRecord(signal: signal, firstSeen: now, lastSeen: now)
            record.state = .sent(runID: runID, date: now)
            archive.records[signal.identity] = record
        }
        for kind in Set(signals.map(\.kind)) {
            archive.updateStats(for: kind) { $0.lastSentAt = now }
        }
    }

    /// The person decided about a finding: `state` from now on, with the
    /// number it has to move away from to come back.
    static func decide(_ identity: String, _ state: WatchSignalState, in archive: inout WatchArchive) {
        guard var record = archive.records[identity] else { return }
        record.state = state
        switch state {
        case .accepted, .dismissed: record.decidedValue = record.signal.value
        case .new, .sent, .snoozed: record.decidedValue = nil
        }
        archive.records[identity] = record
    }
}
