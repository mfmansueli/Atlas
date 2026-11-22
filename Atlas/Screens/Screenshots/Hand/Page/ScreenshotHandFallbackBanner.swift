//
//  ScreenshotHandFallbackBanner.swift
//  Atlas
//

import SwiftUI

/// "Polish uses the English (U.S.) screenshots.": a language without its
/// own on the device, with Start from English (U.S.) and Add Its Own….
struct ScreenshotHandFallbackBanner: View {
    let title: String
    let detail: String
    let primaryName: String
    let canCopy: Bool
    let onCopy: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "info.circle")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text("\(Text(title).fontWeight(.semibold)) \(Text(detail).foregroundStyle(Palette.label2))")
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Spacing.small) {
                if canCopy {
                    Button("Start from \(primaryName)", action: onCopy)
                        .accessibilityIdentifier("screenshots.hand.startFromPrimary")
                }
                Button("Add Its Own…", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("screenshots.hand.addOwn")
            }
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.hand.fallback")
    }
}
