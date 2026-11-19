//
//  EventArtworkViewerLoop.swift
//  Atlas
//

import SwiftUI

/// A concept's moving version in the viewer, as the App Store plays it:
/// muted, on repeat, from the moment it shows; its still until the movie
/// is ready. A click pauses it or plays it again.
struct EventArtworkViewerLoop: View {
    let model: AppPreviewPlayerModel
    let url: URL
    var posterPath: String?

    @State private var poster: CGImage?

    var body: some View {
        ZStack {
            AppPreviewVideoSurface(player: model.player)
                .allowsHitTesting(false)
            if !model.canPlay || (!model.isPlaying && model.seconds == 0) {
                if let poster {
                    Image(decorative: poster, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                } else {
                    Color.black
                }
            }
        }
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture { model.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.isPlaying ? "Pause the loop" : "Play the loop"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.toggle() }
        .accessibilityIdentifier("events.art.viewer.loop")
        .task(id: url) {
            model.loops = true
            model.isMuted = true
            model.load(url, seconds: 0)
            model.play()
            if let posterPath {
                poster = await InAppEventArtworkInspector.thumbnail(URL(fileURLWithPath: posterPath), isVideo: false, maxPixel: 2400)
            }
        }
    }
}
