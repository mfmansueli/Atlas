//
//  ReviewShotsMiss.swift
//  Atlas
//

import Foundation

/// A product a Make Review Screenshots… run didn't capture (README —
/// Pricing: review screenshots, “The run”): the paywall doesn't show it, so
/// the run skipped it; or a check failed on the image twice, so nothing was
/// sent. Its card says which and why, beside Review Screenshot….
struct ReviewShotsMiss: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// The paywall doesn't show the product.
        case skipped
        /// One more try didn't pass the checks either.
        case checkFailed
    }

    var kind: Kind
    /// What the assistant said: “The paywall shows only Monthly and Annual”,
    /// “The price didn’t show”.
    var reason: String
    var client: String

    /// The card's line under “Review screenshot missing”.
    var text: String {
        let reason = Self.sentence(reason)
        switch kind {
        case .skipped:
            if reason.isEmpty { return String(localized: "\(client) skipped it: the paywall doesn’t show it.", comment: "kind:description") }
            return String(localized: "\(client) skipped it. \(reason)", comment: "kind:description")
        case .checkFailed:
            if reason.isEmpty {
                return String(localized: "\(client) tried twice, and a check failed both times. Nothing was sent.", comment: "kind:description")
            }
            return String(localized: "\(client) tried twice, and a check failed both times: \(reason)", comment: "kind:description")
        }
    }

    /// The reason as a sentence: trimmed, with its first letter capital and
    /// a full stop at the end.
    static func sentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        let capital = first.uppercased() + trimmed.dropFirst()
        return ".!?".contains(capital.last ?? ".") ? capital : capital + "."
    }
}
