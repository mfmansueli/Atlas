//
//  ScreenshotCellState.swift
//  Atlas
//

import Foundation

/// A Sets cell's state, shown as a badge under the render so it never
/// relies on color alone.
enum ScreenshotCellState: Hashable, Sendable {
    /// The render matches what's live in App Store Connect.
    case live
    /// Rendered, differs from what's live: goes to Review & Push.
    case notPushed
    /// A check failed; the reason is "Overflow", "Missing glyphs" or
    /// "Wrong size". Never enters Review & Push.
    case failed(reason: String)
    case noCaption
    case noCapture
    /// Not in the scope and nothing live: the App Store shows the primary
    /// locale's set.
    case fallback
    /// Live, but not made from the template.
    case uploadedByHand
    /// Restored and pinned: left alone until Use Template Again.
    case restored
    /// There's no template yet and nothing live.
    case empty
    /// Added by hand, not pushed yet.
    case handNew
    /// Its image replaced by hand, not pushed yet.
    case handReplaced
    /// Deleted by hand: goes when the person pushes.
    case willBeDeleted

    /// The badge text.
    var title: String {
        switch self {
        case .live: String(localized: "Live")
        case .notPushed: String(localized: "Not pushed")
        case let .failed(reason): reason
        case .noCaption: String(localized: "No caption")
        case .noCapture: String(localized: "No capture")
        case .fallback: String(localized: "English (U.S.)")
        case .uploadedByHand: String(localized: "Uploaded by hand")
        case .restored: String(localized: "Restored")
        case .empty: String(localized: "Nothing yet")
        case .handNew: String(localized: "New · not pushed")
        case .handReplaced: String(localized: "Replaced · not pushed")
        case .willBeDeleted: String(localized: "Will be deleted")
        }
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    /// Rendered, or changed by hand, and waiting for Review & Push.
    var isPending: Bool { [.notPushed, .handNew, .handReplaced, .willBeDeleted].contains(self) }
}
