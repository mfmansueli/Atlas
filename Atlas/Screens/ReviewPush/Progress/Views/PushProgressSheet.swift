//
//  PushProgressSheet.swift
//  Atlas
//

import SwiftUI

/// Review & Push once anything is pushed: the changes, the screenshots and
/// the header, search images and App Previews as one push, whichever of
/// them it sends. One title and bar, the time, each failure reason once,
/// a row per change, image or video (a click on a thumbnail opens it
/// large), and the same buttons whatever it sends: Cancel Remaining and
/// Minimize (Esc) while it runs; Retry Failed, View Results, Show in
/// Activity and Done once it's over. Each button acts on all three.
struct PushProgressSheet: View {
    let viewModel: ReviewPushViewModel
    let onViewResults: () -> Void
    /// Review & Push's Activity, on the push that just ended.
    let onShowInActivity: () -> Void
    let onDone: () -> Void
    /// Hides the sheet while the push goes on; the toolbar's Review & Push
    /// shows how far it got and opens it again.
    let onMinimize: () -> Void

    @State private var artwork = PushProgressArtworkCache()

    private var push: PushController { viewModel.push }
    private var screenshots: ScreenshotPushController { push.screenshots }
    private var extras: ExtrasPushController { screenshots.extras }

    /// The thumbnail column of rows that show one.
    private static let thumbnailWidth: CGFloat = 32

    var body: some View {
        let summary = PushProgressSummary(push: push, artwork: artwork.artwork(for:))
        VStack(alignment: .leading, spacing: 0) {
            PushProgressHeader(
                summary: summary, notes: PushProgressNote.notes(for: push, subtitle: summary.subtitle), rateLimit: push.rateLimit
            )
            .padding(.horizontal, Spacing.xLarge)
            .padding(.top, Spacing.xLarge)
            .padding(.bottom, Spacing.medium)
            Divider()
            PushProgressList(
                push: push, artwork: artwork, followedID: summary.entries.last { $0.state == .sending }?.id,
                thumbnailWidth: summary.entries.contains { $0.kind != .change } ? Self.thumbnailWidth : nil,
                onOpen: { viewModel.openPushProgress(at: $0, artwork: artwork.artwork(for:)) }
            )
            Divider()
            PushProgressFooter(
                summary: summary, doneNote: doneNote(summary), cancelHelp: cancelHelp, changedPrices: push.changedPrices,
                onCancelRemaining: cancelRemaining, onMinimize: onMinimize, onRetryFailed: retryFailed, onViewResults: onViewResults,
                onShowInActivity: onShowInActivity, onDone: onDone
            )
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.medium)
        }
    }

    /// "Retry sends only the failed ones.", or once the screenshots all
    /// went: "Live on the App Store once version 1.4 is released."
    private func doneNote(_ summary: PushProgressSummary) -> String {
        if summary.failedCount > 0 { return String(localized: "Retry sends only the failed ones.") }
        guard let run = screenshots.run, run.doneCount > 0 else { return "" }
        let versions = Set(run.plans.map(\.version.versionString))
        guard versions.count == 1, let version = versions.first else { return "" }
        return String(localized: "Live on the App Store once version \(version) is released.")
    }

    private var cancelHelp: String? {
        guard screenshots.run?.isRunning == true else { return nil }
        return String(localized: "Old images are deleted only after new ones are in.")
    }

    /// Stops all three: what's on its way finishes, the rest isn't sent.
    private func cancelRemaining() {
        push.cancelRemaining()
        screenshots.cancelRemaining()
        extras.run?.cancelRemaining()
    }

    /// Sends what failed again, in each push that had a failure.
    private func retryFailed() {
        if push.failedCount > 0 { push.retryFailed() }
        if let run = screenshots.run, run.failedCount > 0 { screenshots.retryFailed() }
        if let run = extras.run, run.failedCount > 0 { run.retryFailed() }
    }
}
