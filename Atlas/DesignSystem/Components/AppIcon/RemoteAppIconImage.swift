//
//  RemoteAppIconImage.swift
//  Atlas
//

import SwiftUI

/// An icon App Store Connect serves, filling its frame without the margin
/// a Mac icon comes with; `placeholder(true)` while it downloads, and
/// `placeholder(false)` if it can't be.
struct RemoteAppIconImage<Placeholder: View>: View {
    let url: URL
    var images: AppIconImages = .shared
    @ViewBuilder var placeholder: (_ isLoading: Bool) -> Placeholder

    @State private var image: CGImage?
    /// The icon whose download has finished, image or not.
    @State private var finishedURL: URL?

    var body: some View {
        Group {
            switch Self.phase(image: image, cached: images.cached(url), finishedURL: finishedURL, url: url) {
            case let .loaded(image):
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            case .loading:
                placeholder(true)
            case .unavailable:
                placeholder(false)
            }
        }
        .task(id: url) {
            image = await images.image(for: url)
            finishedURL = url
        }
    }

    /// The icon when it's here; loading until the download for `url` has
    /// finished, then nothing.
    static func phase(image: CGImage?, cached: CGImage?, finishedURL: URL?, url: URL) -> ImageLoadPhase {
        if let image = image ?? cached { return .loaded(image) }
        return finishedURL == url ? .unavailable : .loading
    }
}
