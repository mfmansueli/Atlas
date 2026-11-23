//
//  ScreenshotHandCurrentImage.swift
//  Atlas
//

import SwiftUI

/// The screenshot a sheet acts on, small, with "Now" under it.
struct ScreenshotHandCurrentImage: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let cell: ScreenshotCell
    var width: CGFloat = 96
    var label: String? = String(localized: "Now")

    var body: some View {
        VStack(spacing: Spacing.xSmall) {
            Group {
                if let image = viewModel.thumbnail(for: cell) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    Palette.fill2
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5))
            if let label {
                Pill(text: label, style: .outline)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Current screenshot"))
    }

    private var height: CGFloat {
        let size = viewModel.pixelSize(for: cell.key.displayType)
        return (width * CGFloat(size.height) / CGFloat(max(1, size.width))).rounded()
    }
}
