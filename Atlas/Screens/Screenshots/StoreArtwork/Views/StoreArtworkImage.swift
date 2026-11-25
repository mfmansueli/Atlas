//
//  StoreArtworkImage.swift
//  Atlas
//

import SwiftUI

/// A header or search image filling its frame: what's live, downloaded
/// through the services' `RemoteImageCache`, or a file waiting in Review &
/// Push, read from the app's Extras folder (its motion loop playing on
/// repeat, muted, unless Reduce Motion or the setting keeps it still). A
/// grey tile with a spinner stands in while it loads.
struct StoreArtworkImage: View {
    let services: any ScreenshotsServices
    let app: StoreApp
    let content: StoreArtworkSlot.Content
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            switch content {
            case let .live(image):
                StoreArtworkLiveImage(services: services, image: image, width: width, height: height)
            case let .file(file):
                AutoplayingLoop(url: loopURL(file)) { _ in
                    ExtrasFileThumbnail(url: services.extrasFileURL(file.fileID, pathExtension: "png", for: app), pixelSize: file.pixelSize, width: width)
                }
            case .noHeader, .searchShots:
                ImageLoadingTile(isLoading: false, systemImage: nil)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func loopURL(_ file: ExtrasArtworkFile) -> URL? {
        file.loop.map { services.extrasFileURL($0.fileID, pathExtension: ExtrasArtworkLoop.pathExtension, for: app) }
    }
}
