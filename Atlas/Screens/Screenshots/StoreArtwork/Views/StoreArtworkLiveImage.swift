//
//  StoreArtworkLiveImage.swift
//  Atlas
//

import SwiftUI

/// A live header or search image: at once when it was decoded before in
/// this launch, else a grey tile with a spinner until it has downloaded.
struct StoreArtworkLiveImage: View {
    let services: any ScreenshotsServices
    let image: LiveArtworkImage
    let width: CGFloat
    let height: CGFloat

    @State private var loaded: CGImage?
    @State private var isLoading = true

    init(services: any ScreenshotsServices, image: LiveArtworkImage, width: CGFloat, height: CGFloat) {
        self.services = services
        self.image = image
        self.width = width
        self.height = height
        _loaded = State(initialValue: services.keptLiveArtworkImage(image, pixelWidth: Self.pixelWidth(width)))
    }

    var body: some View {
        ZStack {
            if let loaded {
                Image(decorative: loaded, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                ImageLoadingTile(isLoading: isLoading, controlSize: width >= 120 ? .small : .mini)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .task(id: image) {
            let pixelWidth = Self.pixelWidth(width)
            if let kept = services.keptLiveArtworkImage(image, pixelWidth: pixelWidth) {
                loaded = kept
                return
            }
            isLoading = true
            let read = await services.liveArtworkImage(image, pixelWidth: pixelWidth)
            guard !Task.isCancelled else { return }
            loaded = read
            isLoading = false
        }
    }

    /// Twice the width for Retina, so the image stays sharp.
    private static func pixelWidth(_ width: CGFloat) -> Int {
        Int(width * 2)
    }
}
