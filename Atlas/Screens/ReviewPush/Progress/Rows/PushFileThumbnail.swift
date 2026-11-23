//
//  PushFileThumbnail.swift
//  Atlas
//

import SwiftUI

/// A small still of a file a push sends, read off the main thread: the
/// image, or a movie's first frame with a play badge. A spinner while it's
/// read; a placeholder when the file's gone.
struct PushFileThumbnail: View {
    let url: URL
    let isVideo: Bool
    let pixelSize: PixelSize
    var maxWidth: CGFloat = 32
    var maxHeight: CGFloat = 36

    @State private var image: CGImage?
    @State private var readURL: URL?

    var body: some View {
        let size = Self.size(of: pixelSize, maxWidth: maxWidth, maxHeight: maxHeight)
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else if readURL != url {
                ImageLoadingTile(controlSize: .mini)
            } else {
                Palette.fill2
                Image(systemName: isVideo ? "play.rectangle" : "photo")
                    .font(.footnote)
                    .foregroundStyle(Palette.label3)
            }
            if isVideo, image != nil {
                Image(systemName: "play.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .depth(.card)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.flag, style: .continuous)
                .strokeBorder(Palette.separator2, lineWidth: 0.5)
        }
        .task(id: url) {
            image = await InAppEventArtworkInspector.thumbnail(url, isVideo: isVideo, maxPixel: Int(max(size.width, size.height) * 3))
            readURL = url
        }
        .accessibilityHidden(true)
    }

    /// `pixelSize` fitted in `maxWidth` × `maxHeight`.
    static func size(of pixelSize: PixelSize, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        let width = CGFloat(max(1, pixelSize.width))
        let height = CGFloat(max(1, pixelSize.height))
        let scale = min(maxWidth / width, maxHeight / height)
        return CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
    }
}
