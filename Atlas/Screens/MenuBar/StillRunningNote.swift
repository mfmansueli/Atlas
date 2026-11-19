//
//  StillRunningNote.swift
//  Atlas
//

import SwiftUI

/// The note under the menu bar icon the first time the window closes:
/// "Atlas is still running", where to find it, and the choice to quit
/// instead (which turns "Keep running when the window is closed" off).
struct StillRunningNote: View {
    let onQuitWhenClosed: () -> Void
    let onDismiss: () -> Void

    static let width: CGFloat = 330

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: AtlasIconGradient.colors(for: colorScheme), startPoint: .top, endPoint: .bottom))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(nsImage: MenuBarGlyph.image(for: .idle, size: 22))
                            .renderingMode(.template)
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Atlas is still running")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Closing the window doesn’t quit it.")
                        .font(.footnote)
                        .foregroundStyle(Palette.label2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("It keeps pushes and Autopilot going, and checks for new reviews and Apple’s answers. Find it here, in the menu bar.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.xSmall) {
                Spacer(minLength: 0)
                Button("Quit When I Close the Window", action: onQuitWhenClosed)
                    .controlSize(.small)
                    .accessibilityIdentifier("stillRunning.quitWhenClosed")
                Button("Got It", action: onDismiss)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("stillRunning.gotIt")
            }
        }
        .padding(14)
        .frame(width: Self.width)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stillRunning.note")
    }
}

#Preview {
    StillRunningNote(onQuitWhenClosed: {}, onDismiss: {})
}
