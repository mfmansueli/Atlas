//
//  ReviewPushTab.swift
//  Atlas
//

import Foundation

/// The two tabs of Review & Push (README-DS §15, board 90): what waits to
/// be pushed, and every push from this Mac. It opens on Activity when
/// nothing waits.
enum ReviewPushTab: String, Hashable, Sendable, CaseIterable, Identifiable {
    case toPush
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toPush: String(localized: "To Push", comment: "kind:segment · Review & Push tab")
        case .activity: String(localized: "Activity", comment: "kind:segment · Review & Push tab")
        }
    }

    /// The tab Review & Push opens on when nothing asked for one.
    static func opening(pendingCount: Int) -> ReviewPushTab {
        pendingCount > 0 ? .toPush : .activity
    }
}
