//
//  RefreshState.swift
//  Atlas
//

import Foundation

/// Where the window's Refresh stands (README-DS §15, board 90). The window
/// owns it (`WorkspaceNavigator.refreshState`): the sidebar's Refresh
/// button shows it (turning, a state dot, the time in its tooltip) and,
/// for `failed`, `offline` and `readOnly`, the toolbar's status line
/// says what happened. Grey and amber are state, never blue or purple.
enum RefreshState: Hashable, Sendable {
    /// Nothing has been read in this window yet.
    case idle
    /// Reading App Store Connect again: the arrow turns and the button is
    /// disabled, so a second click does nothing.
    case refreshing(lastUpdated: Date?)
    /// The last refresh ended well at this time.
    case updated(Date)
    /// The last refresh failed: amber dot, "Couldn’t update · Details…".
    /// What shows is from `lastUpdated`; nothing the person changed is lost.
    case failed(AppleErrorCopy, lastUpdated: Date?)
    /// No network since `since`: grey dot, "Offline · from 14:32".
    case offline(since: Date)
    /// The key can only read (`role` is Apple's name for it, e.g.
    /// "Developer"): lock, "View only · updated 2 min ago".
    case readOnly(role: String, lastUpdated: Date?)

    var isRefreshing: Bool {
        if case .refreshing = self { return true }
        return false
    }

    /// When the window last read App Store Connect without a problem.
    var lastUpdated: Date? {
        switch self {
        case .idle: nil
        case let .refreshing(date): date
        case let .updated(date): date
        case let .failed(_, date): date
        case .offline: nil
        case let .readOnly(_, date): date
        }
    }

    /// The state once a refresh starts: it keeps the last good time for
    /// the tooltip and the error sheet.
    var starting: RefreshState {
        .refreshing(lastUpdated: lastUpdated)
    }

    /// Whether the status line has something to say (README-DS §15: only
    /// when something is wrong).
    var needsStatusLine: Bool {
        switch self {
        case .failed, .offline, .readOnly: true
        case .idle, .refreshing, .updated: false
        }
    }
}
