//
//  AutopilotDoneBounce.swift
//  Atlas
//

import SwiftUI

/// The Autopilot button's one bounce when a run is done: 0.45 s, none
/// with Reduce Motion (`bounces` false). Apart from the generic button
/// face, so the keyframe closures don't capture its menu's type.
struct AutopilotDoneBounce: ViewModifier {
    /// Bumped when a run is done.
    let trigger: Int
    let bounces: Bool

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: 1.0, trigger: trigger) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { [bounces] _ in
                CubicKeyframe(bounces ? 1.07 : 1, duration: 0.2)
                CubicKeyframe(1, duration: 0.25)
            }
    }
}
