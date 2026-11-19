//
//  AskBusyButtonStyle.swift
//  Atlas
//

import SwiftUI

/// An asking button while its app's request runs: suggestion purple on a
/// faint purple capsule, at full color though it can't be pressed, since
/// it says what's happening ("Claude Code Is Working…").
struct AskBusyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(Palette.machineTranslated)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minHeight: 24)
            .background(Palette.suggestionBusyTint, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.suggestionEdge, lineWidth: 1))
    }
}
