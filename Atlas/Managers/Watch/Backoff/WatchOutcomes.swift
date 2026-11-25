//
//  WatchOutcomes.swift
//  Atlas
//

import Foundation

/// What became of a finding a run took, worked out on each check: what the
/// person decided about it (here or on the suggestions the run tagged),
/// whether it's fixed, or nothing for a week.
enum WatchOutcomes {
    /// The suggestions the run tagged for it (`ChangeOrigin.watch`), as the
    /// person left them.
    struct Suggestions: Hashable, Sendable {
        var accepted = 0
        var edited = 0
        var dismissed = 0
        var open = 0
    }

    /// Nil while it can still go either way.
    static func outcome(
        of signal: WatchSignal, record: WatchRecord?, isStillFound: Bool, suggestions: Suggestions = Suggestions(), sentAt: Date, now: Date
    ) -> WatchSignalOutcome? {
        switch record?.state {
        case .accepted: return .accepted
        case .dismissed: return .dismissed
        default: break
        }
        if suggestions.edited > 0 { return .edited }
        if suggestions.accepted > 0 { return .accepted }
        if suggestions.dismissed > 0, suggestions.open == 0 { return .dismissed }
        // Fixed after the run: what's gone counts as taken, unless it only
        // went because its day passed.
        if !isStillFound, signal.deadline.map({ $0 > now }) ?? true { return .accepted }
        if now.timeIntervalSince(sentAt) >= WatchBackoff.settleTime { return .ignored }
        return nil
    }
}
