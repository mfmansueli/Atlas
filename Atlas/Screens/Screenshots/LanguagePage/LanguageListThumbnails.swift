//
//  LanguageListThumbnails.swift
//  Atlas
//

import SwiftUI

/// The strip under a language in All Languages (the canvas's `sh-all`):
/// its own screenshots on the device in view, small, in order, so the
/// languages can be compared at a glance. Clicking one opens the language.
/// A language that uses the primary one's has no strip; its status line
/// already says so.
struct LanguageListThumbnails: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let locale: StoreLocale
    let onOpen: () -> Void

    /// The canvas's sizes: narrow phones, wider iPad and Mac screens.
    private var width: CGFloat {
        viewModel.displayType == .iPhone ? 58 : 96
    }

    var body: some View {
        let items = viewModel.allLanguagesThumbnails(of: locale)
        if !items.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.xSmall) {
                    ForEach(items) { item in
                        Button(action: onOpen) {
                            thumbnail(item.cell)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            // The row's button already reads the language and its count.
            .accessibilityHidden(true)
            .accessibilityIdentifier("screenshots.page.language.\(locale.code).strip")
        }
    }

    private var height: CGFloat {
        let size = viewModel.pixelSize(for: viewModel.displayType)
        return (width * CGFloat(size.height) / CGFloat(max(1, size.width))).rounded()
    }

    private func thumbnail(_ cell: ScreenshotCell) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous)
        return Group {
            if let image = viewModel.thumbnail(for: cell) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ImageLoadingTile(isLoading: viewModel.isRendering(cell) || cell.image.handFile != nil, systemImage: nil)
            }
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.separator2, lineWidth: 0.5))
        .contentShape(shape)
    }
}
