//
//  AutopilotQuestionSheet.swift
//  Atlas
//

import SwiftUI

/// Store Page's Ask Claude Code Something Else…: what to ask, in the
/// person's own words; Ask sends it like any other request (board 56).
struct AutopilotQuestionSheet: View {
    let client: String
    let appName: String
    let onAsk: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""

    private var trimmed: String { question.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Ask \(client)")
                .font(.body.weight(.semibold))
            Text("What should \(client) do for \(appName)? Its changes wait for you, marked in purple.")
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Subtitle about journaling at night", text: $question, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("autopilot.question.field")
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Ask") {
                    onAsk(trimmed)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(trimmed.isEmpty)
                .accessibilityIdentifier("autopilot.question.ask")
            }
        }
        .padding(Spacing.xLarge)
        .frame(width: 440)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autopilot.question")
    }
}
