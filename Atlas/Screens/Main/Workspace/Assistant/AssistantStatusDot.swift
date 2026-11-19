//
//  AssistantStatusDot.swift
//  Atlas
//

import SwiftUI

/// The Assistant button's dot: grey before setup, yellow while waiting for
/// a first call, green once connected; for the app on screen, yellow when
/// it works in another project and red when refused. Never alone: the state is always in
/// words next to it or in the accessibility label.
struct AssistantStatusDot: View {
    let status: AssistantStatus
    /// The connection for the app on screen, which says more than the
    /// status: yellow in another project, red when refused.
    var tone: AssistantConnection.Tone?

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }

    private var color: Color {
        if let tone {
            switch tone {
            case .good: return Palette.positive
            case .attention: return Palette.warningMark
            case .problem: return Palette.dangerMark
            }
        }
        return switch status {
        case .notSetUp: Palette.label3
        case .waiting: Palette.warningMark
        case .connected, .ready: Palette.positive
        }
    }
}

#Preview {
    HStack {
        AssistantStatusDot(status: .notSetUp)
        AssistantStatusDot(status: .waiting(client: "Claude Code"))
        AssistantStatusDot(status: .connected(client: "Claude Code"))
        AssistantStatusDot(status: .ready(client: "Anthropic API"))
    }
    .padding()
}
