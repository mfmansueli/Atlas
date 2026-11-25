//
//  ReviewShotsDebugState.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: where Lumen's review screenshots are in an `rs-*` scene
/// (README — Pricing: review screenshots, boards 65–66).
enum ReviewShotsDebugState: String, CaseIterable, Sendable {
    /// `rs-match`: all three missing; Screenshots has a capture of the
    /// paywall, Use This Capture on each card.
    case match
    /// `rs-none`: all three missing, no capture: Make Review Screenshots….
    case none
    /// `rs-run`: Claude Code capturing Annual, 2 of 3; Monthly arrived.
    case run
    /// `rs-arrived`: the three images suggested, Accept All 3.
    case arrived
    /// `rs-preview`: Show Larger over the three.
    case preview
    /// `rs-fail-nav`: the run couldn't find the paywall.
    case failNav = "fail-nav"
    /// `rs-fail-price`: the paywall showed no prices.
    case failPrice = "fail-price"
    /// `rs-accepted`: Monthly accepted, Annual from Capture 14, Lifetime
    /// in App Store Connect.
    case accepted
    /// `rs-skipped`: Monthly arrived; the run skipped Annual (the paywall
    /// doesn't show it) and Lifetime failed a check twice.
    case skipped
    /// `rs-size`: Monthly accepted, and Apple refused its dimensions in
    /// the last push: Use a 640 × 920 Copy.
    case size
    /// `rs-live`: the three uploaded by a push today, read back from App
    /// Store Connect (Annual still Missing Metadata: its group has no
    /// localization), with the toast after the push.
    case live

    var sceneID: String { "rs-" + rawValue }

    init?(sceneID: String) {
        guard sceneID.hasPrefix("rs-") else { return nil }
        self.init(rawValue: String(sceneID.dropFirst(3)))
    }
}
#endif
