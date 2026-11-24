//
//  InAppEventArtworkCheck.swift
//  Atlas
//

import Foundation

/// One finding about an event card or details page: a refusal is
/// something Apple doesn't take (it can't be queued), a warning something
/// to look at (it still can).
struct InAppEventArtworkCheck: Hashable, Sendable {
    enum Severity: String, Hashable, Sendable {
        case refusal
        case warning
    }

    var severity: Severity
    /// What's wrong and how to fix it.
    var text: String

    var isRefusal: Bool { severity == .refusal }

    static func refusal(_ text: String) -> InAppEventArtworkCheck {
        InAppEventArtworkCheck(severity: .refusal, text: text)
    }

    static func warning(_ text: String) -> InAppEventArtworkCheck {
        InAppEventArtworkCheck(severity: .warning, text: text)
    }
}
