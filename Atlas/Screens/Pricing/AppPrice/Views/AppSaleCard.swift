//
//  AppSaleCard.swift
//  Atlas
//

import SwiftUI

/// The frame the App Price and Availability cards share, as Pricing's
/// product cards look: a title with Not pushed, a caption, a figure on the
/// trailing side, and the card's content.
struct AppSaleCard<Content: View>: View {
    let title: String
    let caption: String
    var figure: String?
    var figureCaption: String?
    var isQueued = false
    let identifier: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xSmall) {
                        Text(title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        if isQueued {
                            Pill(text: String(localized: "Not pushed"), style: .accent)
                                .fixedSize()
                        }
                    }
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.small)
                if let figure {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(figure)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .accessibilityIdentifier("\(identifier).figure")
                        if let figureCaption {
                            Text(figureCaption)
                                .font(.caption2)
                                .foregroundStyle(Palette.label2)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Palette.raised, in: shape)
        .overlay(shape.strokeBorder(isQueued ? Palette.accentTint : Palette.separator, lineWidth: isQueued ? 1 : 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
    }
}
