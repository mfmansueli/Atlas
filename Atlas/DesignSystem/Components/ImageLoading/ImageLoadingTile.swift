//
//  ImageLoadingTile.swift
//  Atlas
//

import SwiftUI

/// What stands in for an image that's still downloading, being read or
/// rendering: its tile with a spinner, so the person sees it's on its way.
/// Once nothing can come (`isLoading` false) the spinner gives way to
/// `systemImage`, or to the bare tile when that's nil. The caller sizes
/// and clips it like the image it stands in for.
struct ImageLoadingTile: View {
    var isLoading = true
    /// The glyph once nothing can come; nil leaves the tile bare.
    var systemImage: String? = "photo"
    var fill: Color = Palette.fill2
    /// `.mini` for icons and list rows, `.small` for thumbnails.
    var controlSize: ControlSize = .small

    var body: some View {
        ZStack {
            fill
            if isLoading {
                ProgressView()
                    .controlSize(controlSize)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(Palette.label3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLoading ? Text("Image, loading") : Text("No image"))
    }
}

#Preview {
    HStack {
        ImageLoadingTile()
            .frame(width: 84, height: 180)
        ImageLoadingTile(isLoading: false)
            .frame(width: 84, height: 180)
        ImageLoadingTile(controlSize: .mini)
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
    }
    .padding()
}
