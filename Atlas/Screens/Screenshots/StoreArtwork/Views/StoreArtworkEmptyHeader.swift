//
//  StoreArtworkEmptyHeader.swift
//  Atlas
//

import SwiftUI

/// Where a header would go, when there's none: a dashed box saying what
/// the App Store shows instead.
struct StoreArtworkEmptyHeader: View {
    var body: some View {
        VStack(spacing: Spacing.tiny) {
            Text("No header", comment: "kind:empty-title")
                .atlasTextStyle(.headline)
            Text("The page starts with the icon and name. Apple shows a header only when you add one.", comment: "kind:empty-body")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
                .strokeBorder(Palette.separator2, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("screenshots.artwork.header.empty")
    }
}
