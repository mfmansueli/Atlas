//
//  AcceptAllShotPair.swift
//  Atlas
//

import CoreGraphics
import SwiftUI

/// A caption's screenshot before → after, beside its suggestion in the
/// Accept All sheet: drawn by the template engine with the caption it has
/// now, dimmed, then with the suggested one in a purple ring (prototype
/// scene `sh-sheet`).
struct AcceptAllShotPair: View {
    let screenshot: AcceptAllScreenshot
    /// The capture each one draws, asked for when it isn't loaded yet.
    let captureImage: @MainActor (SlotPreview) -> CGImage?

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            thumbnail(screenshot.now, isSuggested: false)
                .opacity(0.75)
                .accessibilityLabel(Text("Now"))
            Image(systemName: "chevron.right")
                .atlasTextStyle(.footnote)
                .foregroundStyle(Palette.label3)
                .accessibilityHidden(true)
            thumbnail(screenshot.suggested, isSuggested: true)
                .accessibilityLabel(Text(String(localized: "With the new caption", comment: "kind:accessibility-label")))
        }
        .fixedSize()
        .accessibilityIdentifier("acceptAll.shots")
    }

    private func thumbnail(_ preview: SlotPreview, isSuggested: Bool) -> some View {
        let width = Metrics.captionShotWidth
        let shape = RoundedRectangle(cornerRadius: max(Radius.flag, width * 0.06), style: .continuous)
        return SlotPreviewImage(preview: preview, capture: captureImage(preview), width: width)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(isSuggested ? Palette.aiFill : Palette.separator2, lineWidth: isSuggested ? 2 : 0.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isImage)
    }
}
