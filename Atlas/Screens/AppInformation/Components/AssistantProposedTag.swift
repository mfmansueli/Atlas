//
//  AssistantProposedTag.swift
//  Atlas
//

import SwiftUI

/// "CC Proposed": next to an answer an assistant gave. VoiceOver reads
/// "Proposed by Claude Code".
struct AssistantProposedTag: View {
    let client: String
    var text = String(localized: "Proposed")

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            Text(ChangeSource.assistant(client: client).monogram ?? "")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                .frame(width: 16, height: 16)
                .background(Palette.label, in: RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.leading, 3)
        .padding(.trailing, Spacing.xSmall)
        .padding(.vertical, 2)
        .overlay(Capsule().strokeBorder(Palette.separator2, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(text) by \(client)"))
    }
}

#Preview {
    VStack {
        AssistantProposedTag(client: "Claude Code")
        AssistantProposedTag(client: "Claude Code", text: "Suggested")
    }
    .padding()
}
