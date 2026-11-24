//
//  ProductPageTextSuggestionCard.swift
//  Atlas
//

import SwiftUI

/// An assistant's promotional text for this language: why, what's there
/// now, what it suggests, and Dismiss, Use and Edit or Accept. It arrives,
/// with its text, and settles like any suggestion (effects 2, 3 and 5).
struct ProductPageTextSuggestionCard: View {
    @Bindable var viewModel: ProductPagesViewModel
    let suggestion: ProductPageTextSuggestion
    let current: String
    let isRightToLeft: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false

    var body: some View {
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
                if let confidence = suggestion.layers?.confidence { HowSureMeter(confidence: confidence) }
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: Spacing.xxSmall) {
                GridRow {
                    Text("Now")
                        .font(.footnote.weight(.semibold))
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
                    Text("Suggested")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.ai)
                        .frame(width: 74, alignment: .leading)
                    SuggestedText(suggestion.text, arrivalKey: arrivalKey, arrivedAt: suggestion.createdAt)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                        .accessibilityIdentifier("pages.textSuggestion.value")
                }
            }
            if let gloss = suggestion.layers?.gloss { GlossLine(gloss: gloss) }
            HStack(spacing: Spacing.xSmall) {
                Text("\(suggestion.text.count) / \(ProductPageField.promotionalTextLimit)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Dismiss") { AIDecided.dismiss(reduceMotion: reduceMotion) { viewModel.dismissText(suggestion) } }
                    .accessibilityIdentifier("pages.textSuggestion.dismiss")
                Button("Use and Edit") { viewModel.useAndEdit(suggestion) }
                    .accessibilityIdentifier("pages.textSuggestion.useAndEdit")
                Button("Accept", action: accept)
                    .rowActionButton()
                    .accessibilityIdentifier("pages.textSuggestion.accept")
            }
            .controlSize(.regular)
            if let details = suggestion.layers?.details { SuggestionDetailsDisclosure(details: details) }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .suggestionSurface(isSettling: isSettling, arrivalKey: arrivalKey, arrivedAt: suggestion.createdAt)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Suggested promotional text from \(suggestion.source)"))
        .accessibilityIdentifier("pages.textSuggestion")
    }

    /// The text it shows: a new suggestion in its place arrives again.
    private var arrivalKey: String { "\(suggestion.id)|\(suggestion.text)" }

    private func accept() {
        AIDecided.accept(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            viewModel.acceptText(suggestion)
        }
    }
}
