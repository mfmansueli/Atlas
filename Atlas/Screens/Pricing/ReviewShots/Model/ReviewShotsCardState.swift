//
//  ReviewShotsCardState.swift
//  Atlas
//

import Foundation

/// Where a product's App Review screenshot is, for its card (README —
/// Pricing: review screenshots): missing (with a capture to use, or not),
/// waiting its turn in a run, being captured, suggested, accepted and
/// waiting in Review & Push, or in App Store Connect.
enum ReviewShotsCardState: Equatable {
    /// Not read from App Store Connect yet: nothing to say.
    case unknown
    /// App Store Connect has none, and nothing waits; `capture` is the
    /// Screenshots capture of the paywall, when there is one.
    case missing(capture: ReviewShotsCapture?)
    /// In the run, after the product being captured.
    case queued(String)
    /// Being captured: the steps done, and the one in progress.
    case working(steps: [String], step: String?, client: String, plan: String)
    /// An assistant's image, waiting for Accept or Dismiss.
    case suggested(ReviewShotItem)
    /// Accepted (or picked by hand) and waiting in Review & Push.
    case accepted(ReviewShotItem)
    /// In App Store Connect: uploaded, or still being processed.
    case uploaded(PurchaseReviewScreenshotState)
    /// Apple refused the upload; another one replaces it.
    case failed(PurchaseReviewScreenshotState)

    /// The state of one product's card.
    static func make(
        change: PendingChange?,
        details: ReviewShotDetails?,
        run: ReviewShotsRun?,
        productID: String,
        remote: PurchaseReviewScreenshotState?,
        capture: ReviewShotsCapture?
    ) -> Self {
        if let change, let item = ReviewShotItem(change: change, details: details) {
            return change.awaitingAcceptance == nil ? .accepted(item) : .suggested(item)
        }
        if let run, run.isWorking {
            if run.isCapturing(productID) {
                return .working(steps: run.steps, step: run.step, client: run.client, plan: run.currentProduct?.plan ?? "")
            }
            if run.isQueued(productID) { return .queued(run.queuedText(for: productID)) }
        }
        switch remote {
        case nil: return .unknown
        case .missing?: return .missing(capture: capture)
        case let state? where state.code == "FAILED": return .failed(state)
        case let state?: return .uploaded(state)
        }
    }

    /// Still needs a screenshot: counted as “missing” for the run.
    var needsScreenshot: Bool {
        switch self {
        case .missing, .failed: true
        case .unknown, .queued, .working, .suggested, .accepted, .uploaded: false
        }
    }

    var isSuggested: Bool {
        if case .suggested = self { return true }
        return false
    }

    var isWorking: Bool {
        if case .working = self { return true }
        return false
    }
}
