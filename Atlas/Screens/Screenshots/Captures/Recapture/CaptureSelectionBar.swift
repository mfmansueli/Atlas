//
//  CaptureSelectionBar.swift
//  Atlas
//

import SwiftUI

/// Over the coverage while captures are selected: "3 selected", Replace…
/// (one capture), Capture Again with Claude Code (a capture-only run for
/// just those) and Clear.
struct CaptureSelectionBar: View {
    let captures: CapturesViewModel

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Text(captures.selectionTitle)
                .font(.callout.weight(.medium))
                .accessibilityIdentifier("captures.selection.count")
            Spacer(minLength: Spacing.medium)
            if captures.isReplacing { ProgressView().controlSize(.small) }
            Button("Replace…") {
                if let cell = captures.selection.first { captures.chooseReplacement(for: cell) }
            }
            .disabled(captures.selection.count != 1 || captures.isReplacing)
            .help(captures.selection.count == 1 ? Text("Choose a PNG for this capture") : Text("Select one capture to replace it"))
            .accessibilityIdentifier("captures.selection.replace")
            Button("Capture Again with Claude Code") { captures.captureAgain() }
                .buttonStyle(.borderedProminent)
                .disabled(captures.captureAgainRefusal != nil)
                .help(captures.captureAgainRefusal.map { Text($0) } ?? Text("""
                A run for just these captures: the plan, template and captions stay, and Review & Push sends only the \
                images that change
                """))
                .accessibilityIdentifier("captures.selection.captureAgain")
            Button("Clear") { captures.clearSelection() }
                .accessibilityIdentifier("captures.selection.clear")
        }
        .controlSize(.regular)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.xSmall)
        .background(Palette.accentTint)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("captures.selection")
    }
}
