//
//  PricesByCountrySuggestionBanner.swift
//  Atlas
//

import SwiftUI

/// The page's one banner (board 73): "Suggested prices in 104 countries."
/// with the Built-in source and how sure on the title line, the why and
/// the baseline under it, then the strategy pop-up, Dismiss All and Accept
/// All N…. At 860 × 560 it keeps one line: the why moves to its help, the
/// strategy pop-up to the toolbar, and the source and how sure go first
/// when the line is still too narrow.
struct PricesByCountrySuggestionBanner: View {
    let viewModel: PricingViewModel
    let suggestion: PricingProductCard.Suggestion
    let productName: String
    let howSure: HowSure
    /// What the suggestions stand on, by sales state
    /// (`PricingViewModel.countriesBaseline`).
    let baseline: String
    let isFree: Bool
    let isCompact: Bool
    let onDismissAll: () -> Void
    let onAcceptAll: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
        Group {
            if isCompact {
                HStack(spacing: Spacing.small) {
                    ViewThatFits(in: .horizontal) {
                        titleLine
                        shortTitleLine
                    }
                    Spacer(minLength: Spacing.small)
                    actions
                }
                .help(Text(verbatim: "\(suggestion.reason) \(baseline)"))
            } else {
                HStack(alignment: .top, spacing: Spacing.medium) {
                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                        titleLine
                        Text(suggestion.reason)
                            .atlasTextStyle(.callout)
                            .foregroundStyle(Palette.label2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("countries.banner.why")
                        Text(baseline)
                            .atlasTextStyle(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("countries.banner.baseline")
                    }
                    .layoutPriority(1)
                    Spacer(minLength: Spacing.small)
                    actions
                }
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.aiSurface, in: shape)
        .overlay(shape.strokeBorder(Palette.aiEdge, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countries.banner")
    }

    /// "Suggested prices in 104 countries."
    private var title: String {
        suggestion.count == 1
            ? String(localized: "Suggested price in 1 country.", comment: "kind:banner")
            : String(localized: "Suggested prices in \(suggestion.count) countries.", comment: "kind:banner")
    }

    private var titleLine: some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.ai)
                .accessibilityHidden(true)
            Text(title)
                .atlasTextStyle(.headline)
                .lineLimit(1)
                .accessibilityIdentifier("countries.banner.text")
            SuggestionSourceTag(source: .builtIn)
            HStack(spacing: Spacing.xxSmall) {
                HowSureMeter(confidence: howSure)
                Text(howSure.word)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
            .fixedSize()
            .accessibilityElement(children: .combine)
        }
    }

    /// The title alone, for the narrowest compact line.
    private var shortTitleLine: some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.ai)
                .accessibilityHidden(true)
            Text(title)
                .atlasTextStyle(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.small) {
            if !isCompact {
                PricesByCountryStrategyMenu(viewModel: viewModel)
            }
            Button(String(localized: "Dismiss All", comment: "kind:button"), action: onDismissAll)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("countries.banner.dismissAll")
            Button(action: onAcceptAll) {
                HStack(spacing: Spacing.xxSmall) {
                    Text("Accept All \(suggestion.count)…", comment: "kind:button")
                    if isFree, suggestion.count > 1 { ProChip() }
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(Text("Accept all \(suggestion.count) suggested prices for \(productName)", comment: "kind:label"))
            .accessibilityIdentifier("countries.banner.acceptAll")
        }
        .controlSize(.regular)
        .fixedSize()
    }
}
