//
//  ProductPageTextSuggestionCard.swift
//  Atlas
//

import SwiftUI

/// An assistant's promotional text for this language: why, what's there
/// now, what it suggests, and Dismiss, Use and Edit or Accept.
struct ProductPageTextSuggestionCard: View {
    @Bindable var viewModel: ProductPagesViewModel
    let suggestion: ProductPageTextSuggestion
    let current: String
    let isRightToLeft: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Pill(text: String(localized: "Suggested"), style: .machineTranslated)
                SuggestionSourceTag(source: .assistant(client: suggestion.source))
                Text(suggestion.reason)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let evidence = suggestion.evidenceTitle {
                    Pill(text: evidence, style: .outline)
                        .fixedSize()
                        .accessibilityIdentifier("pages.textSuggestion.evidence")
                }
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: Spacing.xxSmall) {
                GridRow {
                    Text("NOW")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.label2)
                        .frame(width: 74, alignment: .leading)
                    Text(current.isEmpty ? String(localized: "Same as the default page") : current)
                        .font(.subheadline)
                        .foregroundStyle(current.isEmpty ? Palette.label3 : Palette.label2)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, isRightToLeft && !current.isEmpty ? .rightToLeft : .leftToRight)
                }
                GridRow {
                    Text("SUGGESTED")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.machineTranslated)
                        .frame(width: 74, alignment: .leading)
                    Text(suggestion.text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                        .accessibilityIdentifier("pages.textSuggestion.value")
                }
            }
            HStack(spacing: Spacing.xSmall) {
                Text("\(suggestion.text.count) / \(ProductPageField.promotionalTextLimit)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Dismiss") { viewModel.dismissText(suggestion) }
                    .accessibilityIdentifier("pages.textSuggestion.dismiss")
                Button("Use and Edit") { viewModel.useAndEdit(suggestion) }
                    .accessibilityIdentifier("pages.textSuggestion.useAndEdit")
                Button("Accept") { viewModel.acceptText(suggestion) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pages.textSuggestion.accept")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.machineTranslatedTint, in: shape)
        .overlay(shape.strokeBorder(Palette.machineTranslatedMark.opacity(contrast == .increased ? 0.8 : 0.35), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Suggested promotional text from \(suggestion.source)"))
        .accessibilityIdentifier("pages.textSuggestion")
    }
}
