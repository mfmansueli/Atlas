//
//  AssistantWorkingDot.swift
//  Atlas
//

import SwiftUI

/// The Autopilot popover's dot while a request runs: suggestion purple and
/// still (motion v2: nothing pulses while the assistant works).
struct AssistantWorkingDot: View {
    var body: some View {
        Circle()
            .fill(Palette.aiFill)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}
