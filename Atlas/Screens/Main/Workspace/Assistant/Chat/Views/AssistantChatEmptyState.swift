//
//  AssistantChatEmptyState.swift
//  Atlas
//

import SwiftUI

/// An empty chat: what it does, and three questions for this section. Or,
/// without an assistant Atlas can start, the way to connect one.
struct AssistantChatEmptyState: View {
    let appName: String
    let client: String
    let canAsk: Bool
    let starters: [String]
    let onAsk: (String) -> Void
    let onConnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if canAsk {
                Text(
                    "Ask anything about \(appName). Changes come back as suggestions; nothing is sent until you push.",
                    comment: "kind:empty · the chat before the first question"
                )
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    ForEach(starters, id: \.self) { starter in
                        Button {
                            onAsk(starter)
                        } label: {
                            AIStartLabel(starter)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("chat.starter")
                    }
                }
            } else {
                Image(systemName: "text.bubble")
                    .font(.title)
                    .foregroundStyle(Palette.label2)
                    .accessibilityHidden(true)
                Text(
                    "Connect \(client) to ask about \(appName). It reads and suggests; it can’t push.",
                    comment: "kind:empty · the chat without an assistant"
                )
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                Button(String(localized: "Connect…", comment: "kind:button"), action: onConnect)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .accessibilityIdentifier("chat.connect")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.empty")
    }
}

#Preview {
    AssistantChatEmptyState(
        appName: "Lumen", client: "Claude Code", canAsk: true,
        starters: AssistantChatStarters.starters(for: .subscriptionPricing), onAsk: { _ in }, onConnect: {}
    )
    .frame(width: 388, height: 300)
    .padding()
}
