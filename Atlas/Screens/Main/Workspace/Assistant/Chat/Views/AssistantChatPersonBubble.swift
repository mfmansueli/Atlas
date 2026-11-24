//
//  AssistantChatPersonBubble.swift
//  Atlas
//

import SwiftUI

/// What the person wrote, on the right in blue: it's what they did.
struct AssistantChatPersonBubble: View {
    let text: String

    var body: some View {
        // Not selectable: selectable text under an accessibility label of
        // its own sent SwiftUI's label lookup into a loop that crashed Atlas
        // when VoiceOver or XCUITest read it (2026-11-24).
        Text(text)
            .atlasTextStyle(.body)
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.xSmall)
            .background(Palette.accent, in: Self.bubble)
            .frame(maxWidth: Metrics.chatPanelWidth * 0.75, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel(Text("You: \(text)", comment: "kind:accessibility · the person's message in the chat"))
            .accessibilityIdentifier("chat.person")
    }

    /// Square where it points at the person.
    static let bubble = UnevenRoundedRectangle(
        topLeadingRadius: Radius.popover, bottomLeadingRadius: Radius.popover,
        bottomTrailingRadius: Radius.badge, topTrailingRadius: Radius.popover, style: .continuous
    )
}

#Preview {
    AssistantChatPersonBubble(text: "Which countries lose the most sales?")
        .frame(width: Metrics.chatPanelWidth)
        .padding()
}
