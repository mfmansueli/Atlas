//
//  LanguagePageAppPreviewTile.swift
//  Atlas
//

import SwiftUI

/// An App Preview at the start of the language page's row, as the App
/// Store shows it before it plays: its poster frame (loading until it has
/// downloaded), a play button and its length, as tall as the screenshots
/// beside it, with "Live" or "Not pushed" under it. Clicking it plays it.
struct LanguagePageAppPreviewTile: View {
    let item: LanguagePageAppPreview
    let services: any ScreenshotsServices
    /// The row's screenshots' height: the tile is as tall, at its own shape.
    let height: CGFloat
    let onPlay: () -> Void

    @State private var poster: ImageLoadPhase = .loading
    @State private var seconds: Int?
    /// The poster frame's or the file's own shape, once read.
    @State private var readAspect: CGFloat?

    private var aspect: CGFloat { max(readAspect ?? item.aspect, 0.1) }

    private var width: CGFloat { (height / aspect).rounded() }

    var body: some View {
        let slot = shownSlot
        VStack(spacing: Spacing.xSmall) {
            AppPreviewPosterTile(slot: slot, width: width, onPlay: onPlay, playsHere: true)
                .contentShape(Rectangle())
                .onTapGesture(perform: onPlay)
            Pill(text: item.stateTitle, style: item.isPending ? .accent : .outline)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("App Preview \(item.position + 1) of \(item.count), \(item.stateTitle)", comment: "kind:a11y"))
        .accessibilityValue(Text(verbatim: slot.lengthTitle ?? ""))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onPlay() }
        .accessibilityIdentifier("screenshots.page.appPreview.\(item.position + 1)")
        .task(id: item.id) { await load() }
    }

    private var shownSlot: PreviewAppPreviewSlot {
        var slot = item.slot(poster: poster, seconds: seconds)
        slot.aspect = aspect
        return slot
    }

    /// The poster frame through `RemoteImageCache` and the length from the
    /// movie; a file waiting in Review & Push has no poster frame yet, only
    /// its length.
    private func load() async {
        poster = .loading
        seconds = nil
        readAspect = nil
        if let live = item.live {
            let image = await services.livePreviewPoster(live, pixelWidth: Int(width * 2))
            guard !Task.isCancelled else { return }
            poster = ImageLoadPhase(finished: image)
            if let image, image.width > 0 { readAspect = CGFloat(image.height) / CGFloat(image.width) }
            let length = await services.livePreviewSeconds(live)
            guard !Task.isCancelled else { return }
            seconds = length
        } else if let url = item.fileURL {
            poster = .unavailable
            let facts = await ProductPagesViewModel.videoFacts(of: url)
            guard !Task.isCancelled else { return }
            seconds = facts.seconds.map { Int($0.rounded()) }
            if let size = facts.size, size.width > 0 { readAspect = CGFloat(size.height) / CGFloat(size.width) }
        } else {
            poster = .unavailable
        }
    }
}
