//
//  AssistantChatOpening.swift
//  Atlas
//

import SwiftUI

/// How the chat opens and closes (board 69 draws the two states, not the
/// move between them). The pill grows into the panel from the corner they
/// share: the panel starts at the pill's width, anchored bottom-trailing,
/// and widens to its own while it fades in; the pill widens with it as it
/// fades out, so their widths match the whole way. Closing plays it back
/// into the pill. Neither is laid out again on the way: only scaled, so
/// the page under them and the room it leaves the pill never move.
enum AssistantChatOpening: Equatable {
    /// The pill grows into the panel (motion.base).
    case grow
    /// Reduce Motion: the two cross-fade in place (motion.fast).
    case fade

    /// The one to play, from Reduce Motion.
    nonisolated static func style(reduceMotion: Bool) -> Self {
        reduceMotion ? .fade : .grow
    }

    /// The corner the pill and the panel share, which stays put.
    static let anchor = UnitPoint.bottomTrailing

    var token: MotionToken {
        switch self {
        case .grow: MotionTiming.base
        case .fade: MotionTiming.fast
        }
    }

    /// The panel's scale as it starts to open and ends closing: the pill's
    /// width.
    var panelScale: CGFloat {
        switch self {
        case .grow: Metrics.chatPillWidth / Metrics.chatPanelWidth
        case .fade: 1
        }
    }

    /// The pill's scale as it ends fading out and starts coming back: the
    /// panel's width.
    var pillScale: CGFloat {
        switch self {
        case .grow: Metrics.chatPanelWidth / Metrics.chatPillWidth
        case .fade: 1
        }
    }

    var panelTransition: AssistantChatOpeningTransition {
        AssistantChatOpeningTransition(scale: panelScale)
    }

    var pillTransition: AssistantChatOpeningTransition {
        AssistantChatOpeningTransition(scale: pillScale)
    }
}
