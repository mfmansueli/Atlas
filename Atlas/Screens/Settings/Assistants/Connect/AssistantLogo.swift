//
//  AssistantLogo.swift
//  Atlas
//

import SwiftUI

/// An assistant's tile in Settings' list and Connect's sheet: its letters
/// in white on its own color.
struct AssistantLogo: View {
    let assistant: ConnectableAssistant
    var size: CGFloat = 32

    var body: some View {
        Text(verbatim: assistant.monogram)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Self.color(assistant.tileHex), in: RoundedRectangle(cornerRadius: size / 4, style: .continuous))
            .accessibilityHidden(true)
    }

    static func color(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#Preview {
    HStack {
        ForEach(ConnectableAssistant.allCases) { AssistantLogo(assistant: $0) }
    }
    .padding()
}
