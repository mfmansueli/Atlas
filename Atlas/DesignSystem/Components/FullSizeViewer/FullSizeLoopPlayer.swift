//
//  FullSizeLoopPlayer.swift
//  Atlas
//

import SwiftUI

/// A muted loop in a full-size viewer, the way the App Store plays it:
/// its poster until it plays (or right away with `autoplays`), then the
/// movie on repeat. Click it or Play to play or pause, skip or drag
/// through it under it; pinch to zoom. `overlay` is drawn over the movie
/// at its size and zooms with it (the App Store's text over an event's
/// art). Identifiers: `identifier` on the movie and its controls,
/// `zoomIdentifier` on the zoom.
struct FullSizeLoopPlayer<Overlay: View>: View {
    let model: AppPreviewPlayerModel
    let url: URL
    /// The still shown before it plays, read at the size it's drawn.
    let poster: CGImage?
    let width: CGFloat
    /// Height ÷ width.
    let aspect: Double
    let identifier: String
    let zoomIdentifier: String
    /// How tall the controls and their note are.
    var controlsHeight: CGFloat = 64
    var seconds = Double(AutopilotArtworkMotion.loopSeconds)
    var autoplays = false
    var cornerRadius: CGFloat = 4
    @ViewBuilder var overlay: () -> Overlay

    var body: some View {
        VStack(spacing: Spacing.small) {
            ZoomableContainer(identifier: zoomIdentifier, doubleClickZooms: false) {
                Button {
                    model.toggle()
                } label: {
                    video
                }
                .buttonStyle(.plain)
                .help(Text(model.isPlaying ? "Pause" : "Play"))
                .accessibilityLabel(Text(model.isPlaying ? "Pause the loop" : "Play the loop"))
                .accessibilityIdentifier(identifier)
            }
            .frame(width: width, height: height)
            PlayerControls(
                identifier: identifier, isPlaying: model.isPlaying, canPlay: model.canPlay, seconds: model.seconds,
                duration: model.duration, timeTitle: model.timeTitle, toggle: model.toggle, seek: model.seek(to:),
                scrubbing: model.scrub
            ) {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
            .frame(width: max(width, 300), height: controlsHeight - Spacing.small)
        }
        .task(id: url) {
            model.loops = true
            model.isMuted = true
            model.load(url, seconds: seconds)
            if autoplays { model.play() }
        }
    }

    private var height: CGFloat { (width * aspect).rounded() }

    /// The poster until it first plays, and while there's no movie.
    private var showsPoster: Bool {
        !model.canPlay || (!model.isPlaying && model.seconds == 0)
    }

    private var video: some View {
        ZStack {
            AppPreviewVideoSurface(player: model.player)
                .allowsHitTesting(false)
            if showsPoster {
                if let poster {
                    Image(decorative: poster, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Palette.fill2
                }
            }
            overlay()
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(Rectangle())
    }

    /// "Plays muted on repeat on the App Store", or why it can't play.
    private var note: String {
        model.canPlay ? String(localized: "Plays muted on repeat on the App Store") : String(localized: "The loop isn’t on this Mac")
    }
}

extension FullSizeLoopPlayer where Overlay == EmptyView {
    init(
        model: AppPreviewPlayerModel, url: URL, poster: CGImage?, width: CGFloat, aspect: Double, identifier: String, zoomIdentifier: String,
        controlsHeight: CGFloat = 64
    ) {
        self.init(
            model: model, url: url, poster: poster, width: width, aspect: aspect, identifier: identifier, zoomIdentifier: zoomIdentifier,
            controlsHeight: controlsHeight
        ) { EmptyView() }
    }
}
