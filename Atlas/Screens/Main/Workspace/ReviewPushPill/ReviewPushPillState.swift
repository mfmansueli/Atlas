//
//  ReviewPushPillState.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// What Review & Push at the bottom says (board 80): “Up to Date” when
/// nothing waits; blue, with the count, when changes do; “Pushing · 14 of
/// 23” while a push runs, counted from what was sent. In a window under
/// 700 pt it shows its icon and the count only.
enum ReviewPushPillState: Equatable, Sendable {
    case upToDate
    case pending(Int)
    case pushing(sent: Int, total: Int)

    /// `count`: changes, screenshots and extras waiting; `sending`: sent
    /// and total while a push runs.
    init(count: Int, sending: (sent: Int, total: Int)?) {
        if let sending {
            self = .pushing(sent: sending.sent, total: sending.total)
        } else if count > 0 {
            self = .pending(count)
        } else {
            self = .upToDate
        }
    }

    /// Filled blue: something waits or goes.
    var isProminent: Bool { self != .upToDate }

    var title: String {
        switch self {
        case .upToDate: String(localized: "Up to Date", comment: "kind:button")
        case .pending: String(localized: "Review & Push", comment: "kind:button")
        case let .pushing(sent, total): String(localized: "Pushing · \(sent) of \(total)", comment: "kind:button")
        }
    }

    /// The count beside the title: what waits, or “14/23” while pushing
    /// when the title is folded; nil when there's nothing to count.
    func badge(isCompact: Bool) -> String? {
        switch self {
        case .upToDate: nil
        case let .pending(count): count.formatted()
        case let .pushing(sent, total): isCompact ? "\(sent.formatted())/\(total.formatted())" : nil
        }
    }

    /// The number the badge rolls with.
    var count: Int {
        switch self {
        case .upToDate: 0
        case let .pending(count): count
        case let .pushing(sent, _): sent
        }
    }

    var help: String {
        switch self {
        case .upToDate, .pending: String(localized: "Review & Push (⇧⌘P)", comment: "kind:button")
        case let .pushing(sent, total):
            String(localized: "Pushing · \(sent) of \(total) sent. Click for progress (⇧⌘P).", comment: "kind:description")
        }
    }

    var accessibilityValue: String {
        switch self {
        case .upToDate: String(localized: "Up to date", comment: "kind:done-state")
        case .pending(1): String(localized: "1 change ready", comment: "kind:button")
        case let .pending(count): String(localized: "\(count) changes ready", comment: "kind:button")
        case let .pushing(sent, total): String(localized: "Pushing \(sent) of \(total)", comment: "kind:button")
        }
    }

    /// Icon and count only, in a window this narrow; never before the
    /// window is measured.
    static func isCompact(windowWidth: CGFloat) -> Bool {
        windowWidth > 0 && windowWidth < Metrics.reviewPushCompactWindowWidth
    }
}
