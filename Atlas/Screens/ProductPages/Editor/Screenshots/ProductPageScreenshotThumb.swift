//
//  ProductPageScreenshotThumb.swift
//  Atlas
//

import SwiftUI

/// One live screenshot, downloaded at the size it's shown.
struct ProductPageScreenshotThumb: View {
    let services: any ProductPagesServices
    let screenshot: LiveScreenshot
    let device: ProductPageDevice
    let height: CGFloat
    /// The page's own: outlined in the preview.
    var isOutlined = false

    @State private var phase: ImageLoadPhase = .loading
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(3, height / 28), style: .continuous)
        Group {
            if let image = phase.image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                ImageLoadingTile(isLoading: phase.isLoading)
            }
        }
        .frame(width: height * aspect, height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(isOutlined ? Palette.accent : Palette.separator2, lineWidth: isOutlined ? 1.5 : 0.5))
        .task(id: screenshot.id) {
            phase = .loading
            let width = Int((height * aspect * displayScale).rounded())
            phase = await ImageLoadPhase(finished: services.screenshotImage(screenshot, pixelWidth: max(width, 60)))
        }
    }

    private var aspect: CGFloat {
        if let size = screenshot.pixelSize, size.height > 0 { return CGFloat(size.width) / CGFloat(size.height) }
        return Self.aspect(device)
    }

    /// Width over height of a portrait screenshot on the device.
    static func aspect(_ device: ProductPageDevice) -> CGFloat {
        switch device {
        case .iPhone: 1290.0 / 2796.0
        case .iPad: 2048.0 / 2732.0
        }
    }
}
