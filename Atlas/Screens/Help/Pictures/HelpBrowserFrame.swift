//
//  HelpBrowserFrame.swift
//  Atlas
//

import SwiftUI

/// The browser window around a drawn App Store Connect page: three dots,
/// the address, and the page under it in the page's small type.
struct HelpBrowserFrame<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            addressBar
            content
        }
        .padding(.bottom, Spacing.medium)
        .frame(width: Metrics.helpPictureWidth, alignment: .topLeading)
        .atlasTextStyle(.subheadline)
        .foregroundStyle(Palette.label)
        .lineLimit(1)
        .background(Palette.content)
        .clipShape(shape)
        .overlay { shape.strokeBorder(Palette.separator, lineWidth: 0.5) }
        .depth(.card)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }

    private var addressBar: some View {
        HStack(spacing: Spacing.small) {
            dots
            Text(verbatim: "appstoreconnect.apple.com")
                .atlasTextStyle(.footnote)
                .foregroundStyle(Palette.label2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.tiny)
                .background(Palette.content, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
            // The same room on the right, so the address sits in the middle.
            dots.hidden()
        }
        .padding(.vertical, Spacing.xSmall)
        .padding(.horizontal, Spacing.small)
        .background(Palette.fill1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.separator).frame(height: 0.5)
        }
    }

    private var dots: some View {
        HStack(spacing: Spacing.xxSmall) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Palette.fill3)
                    .frame(width: Metrics.helpPictureDot, height: Metrics.helpPictureDot)
            }
        }
    }
}
