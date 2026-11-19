//
//  PushProgressSummary+Live.swift
//  Atlas
//

import Foundation

/// The summary of what Review & Push is sending now: the changes, the
/// screenshot run and the extras run, in the order the sheet lists them.
@MainActor
extension PushProgressSummary {
    init(push: PushController, artwork: @MainActor (PushItem) -> InAppEventArtworkPush?) {
        let shots = push.screenshots.run
        let extras = push.screenshots.extras.run
        var entries: [PushProgressEntry] = []
        if push.phase != .idle {
            entries += push.items.map { PushProgressEntry(item: $0, artwork: artwork($0)) }
        }
        if let shots {
            entries += shots.items.map(PushProgressEntry.init(upload:))
        }
        if let extras {
            entries += extras.items.map { PushProgressEntry(extra: $0, status: extras.status(of: $0)) }
        }
        let starts: [Date?] = [
            push.isRunning ? push.startedAt : nil,
            shots?.isRunning == true ? shots?.date : nil,
            extras?.isRunning == true ? extras?.startedAt : nil,
        ]
        self.init(
            entries: entries,
            isRunning: push.isRunning || shots?.isRunning == true || extras?.isRunning == true,
            isCancelling: shots?.isCancelling == true || extras?.isCancelling == true,
            startedAt: starts.compactMap(\.self).min(),
            pausedUntil: shots?.pausedUntil ?? extras?.pausedUntil
        )
    }

    /// Whether Review & Push shows a push rather than its list: one runs,
    /// or one ended and wasn't dismissed with Done.
    static func isShowing(_ push: PushController) -> Bool {
        push.phase != .idle || push.screenshots.run != nil || push.screenshots.extras.run != nil
    }
}
