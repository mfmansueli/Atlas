//
//  ProductPagesLoadingView.swift
//  Atlas
//

import SwiftUI

/// The first read: what's being read, over rows still loading.
struct ProductPagesLoadingView: View {
    let appName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.small) {
                ProgressView()
                    .controlSize(.small)
                Text("Reading \(appName)’s product pages from App Store Connect…")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: Spacing.large) {
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            SkeletonBlock(width: index == 0 ? 180 : 140, height: 12)
                            SkeletonBlock(width: 220, height: 9)
                        }
                        Spacer(minLength: Spacing.small)
                        SkeletonBlock(width: 110, height: 16, cornerRadius: 8)
                        SkeletonBlock(width: 150, height: 10)
                    }
                    .padding(.horizontal, Spacing.medium)
                    .frame(height: 52)
                    if index < 4 { Divider() }
                }
            }
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pages.loading")
    }
}
