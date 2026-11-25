//
//  PricingPreviewInProductRow.swift
//  Atlas
//

import SwiftUI

/// One product in "Preview in": its name and the price people pay in the
/// chosen country; while it's changing, Suggested or Not pushed and the old
/// price struck through; and about what it is in US dollars. Clicking it
/// opens the product's page on that country.
struct PricingPreviewInProductRow: View {
    let price: PricingPreviewInPrice
    let countryName: String
    let onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Text(price.name)
                        .atlasTextStyle(.callout)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(price.price)
                        .atlasTextStyle(.callout)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .fixedSize()
                }
                // The US dollars beside the old price, else under it.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.xSmall) {
                        change
                        Spacer(minLength: Spacing.xxSmall)
                        dollars
                    }
                    VStack(alignment: .trailing, spacing: Spacing.tiny) {
                        HStack(spacing: Spacing.xSmall) {
                            change
                            Spacer(minLength: 0)
                        }
                        dollars
                    }
                }
            }
            .padding(.horizontal, Spacing.xSmall)
            .padding(.vertical, Spacing.xxSmall)
            .background(
                isHovered ? AnyShapeStyle(Palette.fill1) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -Spacing.xSmall)
        .onHover { isHovered = $0 }
        .help(String(localized: "Open \(price.name) in \(countryName)", comment: "kind:tooltip"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(price.accessibilityText))
        .accessibilityHint(Text("Opens its prices in \(countryName)", comment: "kind:hint"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("pricing.preview.product.\(price.id)")
    }

    /// Suggested or Not pushed, and the old price struck through.
    @ViewBuilder
    private var change: some View {
        if let tag = price.tag {
            Pill(text: tag.title, style: tag == .suggested ? .machineTranslated : .accent)
                .fixedSize()
        }
        if let oldPrice = price.oldPrice {
            Text(oldPrice)
                .strikethrough()
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .monospacedDigit()
                .fixedSize()
        }
    }

    @ViewBuilder
    private var dollars: some View {
        if let dollars = price.dollarsText {
            Text(dollars)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
    }
}
