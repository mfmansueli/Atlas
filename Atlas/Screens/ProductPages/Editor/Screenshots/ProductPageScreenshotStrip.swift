//
//  ProductPageScreenshotStrip.swift
//  Atlas
//

import SwiftUI

/// The screenshots in a row, left to right in every language, at one
/// height; a tile spins while they're read.
struct ProductPageScreenshotStrip: View {
    @Bindable var viewModel: ProductPagesViewModel
    let state: LoadState<[LiveScreenshot]>
    let device: ProductPageDevice
    let height: CGFloat
    var isOwn = false
    /// How many to show; nil shows all.
    var limit: Int?

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                HStack(spacing: Spacing.xSmall) {
                    ForEach(0..<(limit ?? 5), id: \.self) { _ in
                        ImageLoadingTile()
                            .frame(width: height * ProductPageScreenshotThumb.aspect(device), height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                .accessibilityLabel(Text("Reading the screenshots"))
            case let .failed(message):
                InlineMessage.warning(message)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            case let .loaded(shots):
                if shots.isEmpty {
                    Text("No screenshots for \(device.title) in this language.")
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .frame(height: limit == nil ? height : nil)
                } else if limit == nil {
                    ScrollView(.horizontal) {
                        row(shots)
                    }
                    .scrollIndicators(.automatic)
                } else {
                    row(Array(shots.prefix(limit ?? shots.count)))
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.screenshots.strip")
    }

    private func row(_ shots: [LiveScreenshot]) -> some View {
        HStack(spacing: Spacing.xSmall) {
            ForEach(Array(shots.enumerated()), id: \.element.id) { index, shot in
                ProductPageScreenshotThumb(
                    services: viewModel.services, screenshot: shot, device: device, height: height, isOutlined: isOwn
                )
                .accessibilityLabel(Text("Screenshot \(index + 1)"))
            }
        }
    }
}
