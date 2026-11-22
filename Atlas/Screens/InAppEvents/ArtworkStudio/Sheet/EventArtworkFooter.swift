//
//  EventArtworkFooter.swift
//  Atlas
//

import SwiftUI

/// The Brief's footer: "C Claude" and what Make the Artwork makes
/// and how long it takes on the left, Cancel and Make the Artwork on the
/// right.
struct EventArtworkFooter: View {
    @Bindable var flow: EventArtworkFlow
    var onMake: () -> Void = {}

    var body: some View {
        HStack(spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                AssistantChip(name: DesignProjectKind.claude, monogram: "C")
                    .fixedSize()
                Text(flow.summary)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .accessibilityIdentifier("events.art.summary")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Cancel") { flow.close() }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("events.art.cancel")
            Button("Make the Artwork", action: onMake)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!flow.canMake)
                .accessibilityIdentifier("events.art.make")
        }
        .buttonBorderShape(.capsule)
    }
}
