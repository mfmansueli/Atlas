//
//  MenuBarGlyphGallery.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// `mb-glyphs`: the menu bar icon in each state, at 18 points (as in the
/// menu bar) and large, on light and dark bars, then the working loop's
/// eight frames.
struct MenuBarGlyphGallery: View {
    private static let states: [(MenuBarIconState, String)] = [
        (.idle, "Idle"), (.working, "Working"), (.needsYou, "Needs you"), (.paused, "Paused"), (.cantConnect, "Can’t connect"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            HStack(alignment: .top, spacing: Spacing.xLarge) {
                ForEach(Self.states, id: \.1) { state, title in
                    VStack(spacing: Spacing.small) {
                        glyph(state, size: 96)
                            .foregroundStyle(Palette.label)
                        HStack(spacing: 0) {
                            glyph(state, size: 18)
                                .foregroundStyle(.black)
                                .padding(6)
                                .background(Color(white: 0.92))
                            glyph(state, size: 18)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color(white: 0.15))
                        }
                        Text(title)
                            .font(.callout.weight(.semibold))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("glyph.\(title)")
                }
            }
            Text("Working loop · one lap in 2.6 s")
                .font(.headline)
            HStack(spacing: Spacing.large) {
                ForEach(0..<MenuBarGlyph.frameCount, id: \.self) { frame in
                    VStack(spacing: Spacing.xSmall) {
                        Image(nsImage: MenuBarGlyph.image(for: .working, frame: frame, size: 72))
                            .renderingMode(.template)
                            .foregroundStyle(Palette.label)
                        Text("\(frame + 1)")
                            .font(.caption)
                            .foregroundStyle(Palette.label2)
                    }
                }
            }
        }
        .padding(Spacing.xxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Atlas")
    }

    private func glyph(_ state: MenuBarIconState, size: CGFloat) -> some View {
        Image(nsImage: MenuBarGlyph.image(for: state, size: size))
            .renderingMode(.template)
    }
}
#endif
