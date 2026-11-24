//
//  AssistantChatFailureCard.swift
//  Atlas
//

import SwiftUI

/// A turn that stopped with a problem: amber (AI failures are amber), what
/// happened and that nothing changed, Try Again, and the technical words
/// in Details.
struct AssistantChatFailureCard: View {
    let failure: ClaudeCodeRunFailure
    let client: String
    let onRetry: () -> Void
    let onShowOutput: (() -> Void)?

    @State private var showsDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("\(client) stopped", comment: "kind:title · a chat answer that failed")
                .atlasTextStyle(.headline)
            Text("\(failure.title). Nothing changed in Atlas.", comment: "kind:why · a chat answer that failed")
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.small) {
                Button(String(localized: "Try Again", comment: "kind:button"), action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .accessibilityIdentifier("chat.retry")
                if let onShowOutput {
                    Button(String(localized: "Show Output", comment: "kind:button"), action: onShowOutput)
                        .plainButton()
                }
                Spacer(minLength: 0)
                Button(showsDetails ? String(localized: "Hide Details", comment: "kind:button") : String(localized: "Details", comment: "kind:button")) {
                    showsDetails.toggle()
                }
                .plainButton()
            }
            if showsDetails {
                Text(failure.detail)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small + Spacing.tiny)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .aiFailureArrival(key: failure.title)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.failure")
    }
}

#Preview {
    AssistantChatFailureCard(failure: .claudeError("Overloaded"), client: "Claude Code", onRetry: {}, onShowOutput: {})
        .frame(width: 380)
        .padding()
}
