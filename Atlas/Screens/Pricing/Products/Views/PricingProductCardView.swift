//
//  PricingProductCardView.swift
//  Atlas
//

import SwiftUI

/// One product on the Prices page: its name, kind and product ID, Not
/// pushed and its price in the base territory, together one button with a
/// chevron that opens the product's page (board 73); the bar of how its
/// prices are set, and its open suggestion with Show Countries (the page
/// on its suggested prices), Dismiss and Accept. Accepted, the suggestion
/// settles (effect 5): its tint goes, a check draws, and it closes once
/// the prices are queued.
struct PricingProductCardView: View {
    let card: PricingProductCard
    /// The top of the card: the product's page.
    let onOpenPage: () -> Void
    /// Show Countries: the product's page on its suggested prices.
    let onShowCountries: () -> Void
    let onDismiss: () -> Void
    let onAccept: () -> Void
    /// False when Accept opens the paywall instead of accepting.
    var settlesOnAccept = true
    /// Its review screenshot and introductory offer.
    var setupRow: AnyView?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                PricingPriceBar(card: card)
                Text(card.legend)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let suggestion = card.suggestion {
                suggestionBox(suggestion)
            } else if card.isSettingStartingPrices {
                Label(PricingProductCard.settingStartingPricesText, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pricing.card.settingStartingPrices")
            }
            if let setupRow { setupRow }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raised, in: shape)
        .overlay(
            shape.strokeBorder(card.suggestion == nil ? Palette.separator : Palette.aiFill.opacity(0.6), lineWidth: card.suggestion == nil ? 0.5 : 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.card.\(card.product.productID)")
    }

    /// Name, kind and product ID, Not pushed and the base price: one
    /// button, with a chevron, that opens the product's page.
    private var header: some View {
        Button(action: onOpenPage) {
            HStack(alignment: .center, spacing: Spacing.small) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xSmall) {
                        Text(card.product.name)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                        if card.hasQueuedChanges {
                            Pill(text: String(localized: "Not pushed"), style: .accent)
                                .fixedSize()
                        }
                    }
                    Text("\(card.kindText) · \(card.product.productID)")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: Spacing.small)
                if let price = card.basePrice {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(price)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        Text(card.baseTerritoryText)
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Palette.label3)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xSmall)
            .background(isHovered ? Palette.fill1 : .clear, in: headerShape)
            .contentShape(headerShape)
        }
        .buttonStyle(.plain)
        // The hover fill reaches past the card's text, as a row's does.
        .padding(.horizontal, -Spacing.small)
        .padding(.vertical, -Spacing.xSmall)
        .onHover { isHovered = $0 }
        .help(String(localized: "Opens \(card.product.name)’s page: prices in every country, offers and details", comment: "kind:help"))
        .accessibilityLabel(Text(openLabel))
        .accessibilityValue(Text(openValue))
        .accessibilityIdentifier("pricing.card.openPage")
    }

    private var headerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }

    /// "Open Lumen Plus Annual, prices in 175 countries and regions".
    private var openLabel: String {
        card.territoryCount == 1
            ? String(localized: "Open \(card.product.name), prices in 1 country or region", comment: "kind:accessibility-label")
            : String(localized: "Open \(card.product.name), prices in \(card.territoryCount) countries and regions", comment: "kind:accessibility-label")
    }

    /// "$39.99 in the United States, not pushed".
    private var openValue: String {
        let price = card.basePrice.map { "\($0) \(card.baseTerritoryText)" } ?? ""
        guard card.hasQueuedChanges else { return price }
        return price.isEmpty
            ? String(localized: "Not pushed")
            : String(localized: "\(price), not pushed", comment: "kind:accessibility-label")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
    }

    private func suggestionBox(_ suggestion: PricingProductCard.Suggestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "sparkle")
                    .imageScale(.small)
                    .foregroundStyle(Palette.ai)
                    .accessibilityHidden(true)
                Text("Suggested")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ai)
                SuggestionSourceTag(source: .builtIn)
            }
            Text(suggestion.title)
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pricing.card.suggestion")
            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.small) {
                Button("Show Countries", action: onShowCountries)
                    .help(String(localized: "Opens \(card.product.name)’s prices by country, on the suggested ones", comment: "kind:help"))
                    .accessibilityIdentifier("pricing.card.showCountries")
                Spacer(minLength: Spacing.small)
                Button("Dismiss") { AIDecided.dismiss(reduceMotion: reduceMotion, commit: onDismiss) }
                    .accessibilityIdentifier("pricing.card.dismiss")
                // A row action (README — Design system §4): tinted, so the
                // banner's Accept All stays the one filled button.
                Button("Accept", action: accept)
                    .rowActionButton()
                    .accessibilityIdentifier("pricing.card.accept")
            }
            .controlSize(.regular)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Spacing.small)
        .background(isSettling ? Palette.fill1 : Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .aiDecided(isSettling: isSettling)
        .task(id: isSettling) {
            // Still here a while later: the prices weren't queued (an
            // error, the paywall closed), so it takes clicks again.
            guard isSettling else { return }
            try? await Task.sleep(for: .seconds(3))
            withAnimation(MotionTiming.base.animation) { isSettling = false }
        }
        .accessibilityElement(children: .contain)
    }

    private func accept() {
        guard settlesOnAccept else {
            onAccept()
            return
        }
        AIDecided.accept(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            onAccept()
        }
    }
}
