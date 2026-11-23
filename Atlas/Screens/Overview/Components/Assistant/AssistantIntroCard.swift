//
//  AssistantIntroCard.swift
//  Atlas
//

import SwiftUI

/// The overview's card about using your own AI assistant or an API key,
/// until one is set up or the card is hidden: one line on what it brings,
/// Set Up Assistant… (or Finish Setup…) and What Can It Do?. The steps
/// themselves are in the setup sheet and Settings → AI Assistants, so the
/// three lists stay on the first screen.
struct AssistantIntroCard: View {
    let appName: String
    let status: AssistantStatus
    let onSetUp: () -> Void
    let onWhatItDoes: () -> Void
    let onHide: () -> Void

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: Spacing.medium) {
                Image(systemName: "terminal")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.accentText)
                    .frame(width: 26, height: 26)
                    .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    HStack(spacing: Spacing.small) {
                        Text("Use your own AI assistant or API key with Atlas")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Pill(text: statusText, style: status.isWaiting ? .warning : .outline)
                            .fixedSize()
                            .accessibilityIdentifier("overview.assistantIntro.status")
                    }
                    Text("""
                    Your assistant reads \(appName)’s code and suggests store text, answers and captions. Every suggestion \
                    waits here for you; nothing goes to App Store Connect until you push.
                    """)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Spacing.small) {
                        Button(status.setupTitle, action: onSetUp)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("overview.assistantIntro.setUp")
                        Button("What Can It Do?", action: onWhatItDoes)
                            .accessibilityIdentifier("overview.assistantIntro.whatItDoes")
                    }
                    .controlSize(.large)
                    .padding(.top, Spacing.xxSmall)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onHide) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Hide this card"))
                .accessibilityLabel(Text("Hide this card"))
                .accessibilityIdentifier("overview.assistantIntro.hide")
            }
        }
        .accessibilityIdentifier("overview.assistantIntro")
    }

    /// "Not set up", or "Waiting for Claude Code".
    private var statusText: String {
        guard status.isWaiting, let client = status.clientName else { return status.title }
        return String(localized: "Waiting for \(client)")
    }
}

#Preview {
    VStack {
        AssistantIntroCard(appName: "Lumen Journal", status: .notSetUp, onSetUp: {}, onWhatItDoes: {}, onHide: {})
        AssistantIntroCard(appName: "Lumen Journal", status: .waiting(client: "Claude Code"), onSetUp: {}, onWhatItDoes: {}, onHide: {})
    }
    .padding()
    .frame(width: 900)
}
