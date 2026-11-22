//
//  FindingSourceMark.swift
//  Atlas
//

import SwiftUI

/// Who saw a finding: "AL Built-in", "CC Claude Code", as suggestions
/// mark their source.
struct FindingSourceMark: View {
    let source: FindingSource

    var body: some View {
        HStack(spacing: 4) {
            AssistantMonogram(letters: source.mark)
            Text(source.title)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("From \(source.title)"))
    }
}
