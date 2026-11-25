//
//  PricingProductBreadcrumb.swift
//  Atlas
//

import SwiftUI

/// "‹ Pricing › Lumen Plus Annual" over a product's page (board 73):
/// Pricing goes back to the product cards, and so does ⌘[. At its right,
/// ⌃ ⌄ open the previous and next product (⌥⌘↑ / ⌥⌘↓). At 860 × 560 the
/// base price joins the row.
struct PricingProductBreadcrumb: View {
    let productName: String
    /// "$9.99", shown in the row when the page is compact.
    var basePrice: String?
    var hasPrevious = false
    var hasNext = false
    let onBack: () -> Void
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            Button(action: onBack) {
                HStack(spacing: Spacing.tiny) {
                    Image(systemName: "chevron.left")
                        .accessibilityHidden(true)
                    Text(String(localized: "Pricing", comment: "kind:button"))
                }
            }
            .plainButton()
            .keyboardShortcut("[", modifiers: .command)
            .help(String(localized: "Back to Pricing  ⌘[", comment: "kind:help"))
            .accessibilityLabel(Text(String(localized: "Back to Pricing", comment: "kind:accessibility-label")))
            .accessibilityIdentifier("pricing.product.back")
            Image(systemName: "chevron.right")
                .atlasTextStyle(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.label3)
                .accessibilityHidden(true)
            Text(productName)
                .atlasTextStyle(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
            if let basePrice {
                Text(verbatim: "· \(basePrice)")
                    .atlasTextStyle(.headline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityIdentifier("pricing.product.breadcrumb.basePrice")
            }
            Spacer(minLength: Spacing.small)
            ControlGroup {
                Button(String(localized: "Previous Product", comment: "kind:button"), systemImage: "chevron.up", action: onPrevious)
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command])
                    .disabled(!hasPrevious)
                    .help(String(localized: "Previous product  ⌥⌘↑", comment: "kind:tooltip"))
                    .accessibilityIdentifier("pricing.product.previous")
                Button(String(localized: "Next Product", comment: "kind:button"), systemImage: "chevron.down", action: onNext)
                    .keyboardShortcut(.downArrow, modifiers: [.option, .command])
                    .disabled(!hasNext)
                    .help(String(localized: "Next product  ⌥⌘↓", comment: "kind:tooltip"))
                    .accessibilityIdentifier("pricing.product.next")
            }
            .labelStyle(.iconOnly)
            .controlSize(.small)
            .fixedSize()
        }
        .atlasTextStyle(.callout)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.product.breadcrumb")
    }
}

#Preview {
    PricingProductBreadcrumb(productName: "Lumen Plus Annual", hasNext: true) {}
        .padding()
}
