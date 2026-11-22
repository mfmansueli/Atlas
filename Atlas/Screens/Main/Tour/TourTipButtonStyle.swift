//
//  TourTipButtonStyle.swift
//  Atlas
//

import SwiftUI

/// A tip's Next and Skip the Tour: words in the accent color, no bezel.
/// Still a button to VoiceOver, not a link.
struct TourTipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Palette.accentText)
            .lineLimit(1)
            .fixedSize()
            .frame(height: 24)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
