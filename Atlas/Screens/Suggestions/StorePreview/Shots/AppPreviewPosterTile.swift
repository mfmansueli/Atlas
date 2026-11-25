//
//  AppPreviewPosterTile.swift
//  Atlas
//

import SwiftUI

/// The App Preview at the start of the App Store preview's row, as the App
/// Store shows it before it plays: its poster frame, a play button and its
/// length. Play opens the App Preview in Screenshots: Atlas can't play a
/// live App Preview itself. On the Screenshots language page (`playsHere`)
/// it plays it.
struct AppPreviewPosterTile: View {
    let slot: PreviewAppPreviewSlot
    let width: CGFloat
    /// Nil where there's nowhere to open it; the button then hides.
    var onPlay: (() -> Void)?
    /// Play plays it here (the Screenshots language page) instead of
    /// opening Screenshots.
    var playsHere = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        ZStack {
            if let image = slot.poster.image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
                // A veil so the play button reads on any frame.
                Color.black.opacity(0.18)
            } else {
                ImageLoadingTile(isLoading: slot.poster.isLoading, systemImage: nil)
            }
            if !slot.poster.isLoading, let onPlay {
                playButton(onPlay)
            }
        }
        .frame(width: width, height: (width * slot.aspect).rounded())
        .overlay(alignment: .bottomLeading) { length }
        .clipShape(shape)
        .overlay { shape.strokeBorder(Palette.separator2, lineWidth: 0.5) }
        .animation(MotionTiming.fast.animation, value: slot.poster.image != nil)
    }

    private func playButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "play.fill")
                .atlasTextStyle(.callout)
                .foregroundStyle(.black)
                .padding(Spacing.small)
                .background(.white.opacity(0.92), in: Circle())
                .depth(.popover)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(playsHere ? String(localized: "Play the App Preview") : String(localized: "Open the App Preview in Screenshots", comment: "kind:help"))
        .accessibilityLabel(playsHere ? Text("Play the App Preview") : Text("Open the App Preview in Screenshots", comment: "kind:button"))
        .accessibilityIdentifier(playsHere ? "screenshots.page.appPreview.play" : "storePreview.appPreview.play")
    }

    @ViewBuilder
    private var length: some View {
        if let title = slot.lengthTitle {
            Text(verbatim: title)
                .atlasTextStyle(.footnote)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.xxSmall)
                .padding(.vertical, Spacing.tiny)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.badge, style: .continuous))
                .padding(Spacing.xSmall)
                .accessibilityHidden(true)
        }
    }
}
