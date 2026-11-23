//
//  PricingProductCardView.swift
//  Atlas
//

import SwiftUI

/// One product on the Prices page: its name, kind and product ID, Not
/// pushed, its price in the base territory, the bar of how its prices are
/// set, and its open suggestion with Show Countries, Dismiss and Accept.
/// Accepted, the suggestion settles (effect 5): its tint goes, a check
/// draws, and it closes once the prices are queued.
struct PricingProductCardView: View {
    let card: PricingProductCard
    let isExpanded: Bool
    let onToggleCountries: () -> Void
    let onDismiss: () -> Void
    let onAccept: () -> Void
    /// False when Accept opens the paywall instead of accepting.
    var settlesOnAccept = true
    /// Edit Prices…: the product's matrix.
    let onOpen: () -> Void
    /// Its review screenshot and introductory offer, above Edit Prices….
    var setupRow: AnyView?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
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
                            .font(.footnote)
                            .foregroundStyle(Palette.label2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
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
            HStack {
                Spacer()
                // In-app purchase prices are shown, not changed.
                Button(card.product.isInAppPurchase ? "See Prices…" : "Edit Prices…", action: onOpen)
                    .buttonStyle(.link)
                    .controlSize(.regular)
                    .accessibilityLabel(
                        card.product.isInAppPurchase ? Text("See every price of \(card.product.name)") : Text("Edit every price of \(card.product.name)")
                    )
                    .accessibilityIdentifier("pricing.card.open")
            }
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
                Button(isExpanded ? "Hide Countries" : "Show Countries", action: onToggleCountries)
                    .accessibilityIdentifier("pricing.card.countriesToggle")
                Spacer(minLength: Spacing.small)
                Button("Dismiss", action: onDismiss)
                    .accessibilityIdentifier("pricing.card.dismiss")
                // A row action (README — Design system §4): tinted, so the
                // banner's Accept All stays the one filled button.
                Button("Accept", action: accept)
                    .rowActionButton()
                    .accessibilityIdentifier("pricing.card.accept")
            }
            .controlSize(.regular)
            if isExpanded {
                PricingCountriesTable(suggestion: suggestion)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Spacing.small)
        .background(isSettling ? Palette.fill1 : Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .modifier(AcceptSettle(isSettling: isSettling))
        .task(id: isSettling) {
            // Still here a while later: the prices weren't queued (an
            // error, the paywall closed), so it takes clicks again.
            guard isSettling else { return }
            try? await Task.sleep(for: .seconds(3))
            withAnimation(MotionTiming.acceptTint) { isSettling = false }
        }
        .accessibilityElement(children: .contain)
    }

    private func accept() {
        guard settlesOnAccept else {
            onAccept()
            return
        }
        AcceptSettle.perform(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            onAccept()
        }
    }
}
