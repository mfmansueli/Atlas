//
//  AssistantChatSuggestionCard.swift
//  Atlas
//

import SwiftUI

/// What an answer suggested, as a suggestion card in the chat: how many
/// and where, the first of them, and the way to them. Each one waits in
/// its section (and Review & Push once accepted): nothing is sent yet.
struct AssistantChatSuggestionCard: View {
    let suggestions: AssistantChatSuggestions
    let client: String
    let onShow: (AppWorkspaceSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.xSmall) {
                Pill(text: String(localized: "Suggested", comment: "kind:pill"), style: .machineTranslated)
                Text(client)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            Text(suggestions.title)
                .atlasTextStyle(.headline)
                .accessibilityIdentifier("chat.suggestions.title")
            if !suggestions.why.isEmpty {
                Text(suggestions.why)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
            }
            if let section = suggestions.section {
                Button(String(localized: "Show in \(section.title)", comment: "kind:button · opens the section a chat suggestion waits in")) {
                    onShow(section)
                }
                .rowActionButton()
                .accessibilityIdentifier("chat.suggestions.show")
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small + Spacing.tiny)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.aiEdge, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.suggestions")
    }
}

#Preview {
    AssistantChatSuggestionCard(
        suggestions: AssistantChatSuggestions(targets: ["Annual · Brazil", "Annual · India", "Annual · Mexico"], section: .subscriptionPricing),
        client: "Claude Code", onShow: { _ in }
    )
    .frame(width: 380)
    .padding()
}
