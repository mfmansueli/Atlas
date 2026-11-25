//
//  AssistantChatOpeningTransition.swift
//  Atlas
//

import SwiftUI

/// The pill's or the panel's side of `AssistantChatOpening`: away, it is
/// scaled to the other's width from their shared corner and transparent.
struct AssistantChatOpeningTransition: Transition {
    let scale: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : scale, anchor: AssistantChatOpening.anchor)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}
