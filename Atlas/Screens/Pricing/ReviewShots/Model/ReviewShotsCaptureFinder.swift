//
//  ReviewShotsCaptureFinder.swift
//  Atlas
//

import Foundation

/// Finds the paywall among the app's Screenshots captures: a screen of the
/// last Autopilot run named for it (“Paywall”, “Lumen Plus”, “Upgrade”…),
/// captured in the plan's primary language, on iPhone first, the best
/// scored and newest first.
enum ReviewShotsCaptureFinder {
    /// The words a paywall screen's name has, as its id's parts.
    static let words: Set<String> = [
        "paywall", "plus", "premium", "pro", "subscribe", "subscription", "subscriptions", "upgrade", "unlock", "purchase", "plans",
        "membership",
    ]

    /// Whether `screen` is the paywall, by its name.
    static func isPaywall(_ screen: AutopilotScreen) -> Bool {
        let nameParts: [Substring] = AutopilotScreen.identifier(for: screen.name).split(separator: "-")
        let idParts: [Substring] = screen.id.split(separator: "-")
        return (nameParts + idParts).contains { words.contains(String($0)) }
    }

    /// The capture to offer, if the run has one of the paywall.
    static func find(in run: AutopilotRun?) -> ReviewShotsCapture? {
        guard let run else { return nil }
        let screens = run.plan.screens.enumerated().filter { isPaywall($0.element) }
        guard !screens.isEmpty else { return nil }
        let numbers = Dictionary(screens.map { ($0.element.id, $0.offset + 1) }) { first, _ in first }
        let names = Dictionary(screens.map { ($0.element.id, $0.element.name) }) { first, _ in first }
        let candidates = run.captures.filter { numbers[$0.target.screenID] != nil && $0.target.locale == run.plan.primaryLocale }
        let best = candidates.max { lhs, rhs in
            let left = (lhs.target.displayType == .iPhone ? 1 : 0, lhs.score, lhs.receivedAt)
            let right = (rhs.target.displayType == .iPhone ? 1 : 0, rhs.score, rhs.receivedAt)
            return left < right
        }
        guard let best, let number = numbers[best.target.screenID] else { return nil }
        return ReviewShotsCapture(
            captureID: best.captureID, number: number, screenName: names[best.target.screenID] ?? "",
            takenAt: best.receivedAt, displayType: best.target.displayType, locale: best.target.locale, pixelSize: best.pixelSize
        )
    }
}
