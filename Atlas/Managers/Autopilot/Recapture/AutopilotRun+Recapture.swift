//
//  AutopilotRun+Recapture.swift
//  Atlas
//

import Foundation

/// A capture-only run's captures: the old ones of the screens it redoes
/// stop counting once it opens, Pick shows only the new ones, and each
/// redone screen takes the capture picked for it (its best new one unless
/// the person kept the old).
extension AutopilotRun {
    /// The run redoes only some captures.
    var isRecapturing: Bool { recapture != nil && recapture?.placedAt == nil }

    /// A capture from before a capture-only run opened, of a screen it
    /// redoes: it no longer counts, unless the person kept it at Pick.
    func isRedone(_ capture: AutopilotCapture) -> Bool {
        guard let recapture, recapture.placedAt == nil, recapture.covers(capture.target) else { return false }
        return recapture.previousCaptures.contains { $0.id == capture.id }
    }

    /// The capture a redone screen had before the run opened: Pick shows
    /// it beside the new ones.
    func previousCapture(for target: AutopilotCaptureTarget) -> AutopilotCapture? {
        guard let recapture else { return nil }
        return recapture.previousCaptures.filter { $0.target == target && plan.fits($0) }
            .max { $0.score < $1.score || ($0.score == $1.score && $0.receivedAt < $1.receivedAt) }
    }

    /// The capture picked for a redone screen: the one chosen at Pick, else
    /// its best new one. Nil for a screen the run doesn't redo.
    func recaptureChoice(for target: AutopilotCaptureTarget) -> AutopilotCapture? {
        guard let recapture, recapture.covers(target) else { return nil }
        if let id = recapture.picks[target.key],
           let chosen = (captures + recapture.previousCaptures).first(where: { $0.id == id && $0.target == target })
        {
            return chosen
        }
        return captures(for: target).first ?? previousCapture(for: target)
    }

    /// Whether the person kept the old capture of a redone screen.
    func keepsPrevious(_ target: AutopilotCaptureTarget) -> Bool {
        guard let id = recapture?.picks[target.key] else { return false }
        return previousCapture(for: target)?.id == id
    }

    /// Pick shows the redone captures: the run redoes screens and stops
    /// for the person to pick.
    var picksRecaptures: Bool {
        recapture?.targets.isEmpty == false && plan.stopsToPick
    }

    /// The redone screens with a new capture, in the plan's order: what
    /// Pick shows.
    var recapturePickTargets: [AutopilotCaptureTarget] {
        let redone = Set(recapture?.targets ?? [])
        return plan.targets.filter { redone.contains($0) && !captures(for: $0).isEmpty }
    }

    /// "Redoing 18 captures in ja", what the strip and Making it say.
    var recaptureTitle: String? {
        guard let recapture else { return nil }
        return String(localized: "Redoing \(recapture.title)")
    }

    /// The App Preview's moments a capture-only run records again, still
    /// waiting for their takes.
    var recaptureMomentsLeft: [String] {
        guard let ids = recapture?.momentIDs, !ids.isEmpty else { return [] }
        let waiting = Set(retakeTargets.map(\.screenID))
        return ids.filter(waiting.contains)
    }
}
