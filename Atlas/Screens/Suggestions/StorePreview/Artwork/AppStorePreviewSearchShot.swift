//
//  AppStorePreviewSearchShot.swift
//  Atlas
//

import SwiftUI

/// One of screenshots 1–3 in the "In search results" card: at once when
/// decoded before, else a grey tile with a spinner until it downloads.
struct AppStorePreviewSearchShot: View {
    let services: any ScreenshotsServices
    let shot: LiveScreenshot
    let width: CGFloat

    @State private var image: CGImage?
    @State private var isLoading = true

    init(services: any ScreenshotsServices, shot: LiveScreenshot, width: CGFloat) {
        self.services = services
        self.shot = shot
        self.width = width
        _image = State(initialValue: services.keptLiveImage(shot, pixelWidth: Self.pixelWidth(width)))
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                ImageLoadingTile(isLoading: isLoading, controlSize: .mini)
            }
        }
        .frame(width: width, height: (width * aspect).rounded())
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.separator2, lineWidth: 0.5))
        .task(id: shot.id) {
            guard image == nil else { return }
            isLoading = true
            let read = await services.liveImage(shot, pixelWidth: Self.pixelWidth(width))
            guard !Task.isCancelled else { return }
            image = read
            isLoading = false
        }
    }

    /// Height ÷ width, from the screenshot's size.
    private var aspect: CGFloat {
        guard let size = shot.pixelSize, size.width > 0 else { return PreviewShotsStrip.placeholderAspect }
        return CGFloat(size.height) / CGFloat(size.width)
    }

    private static func pixelWidth(_ width: CGFloat) -> Int {
        Int(width * 3)
    }
}
