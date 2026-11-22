//
//  ProductPageSuggestionRow.swift
//  Atlas
//

import SwiftUI

/// One suggested page: its name, who it's for, why with its evidence, and
/// what's in it once shown (keywords, promotional text, screenshots, deep
/// link).
struct ProductPageSuggestionRow: View {
    @Bindable var viewModel: ProductPagesViewModel
    let suggestion: ProductPageSuggestion
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if isCompact {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    summary
                    actions
                }
            } else {
                HStack(alignment: .top, spacing: Spacing.large) {
                    summary.frame(maxWidth: .infinity, alignment: .leading)
                    actions
                }
            }
            if isExpanded {
                ProductPageSuggestionDetails(viewModel: viewModel, suggestion: suggestion)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.suggestion.\(suggestion.id)")
    }

    private var isExpanded: Bool { viewModel.expandedSuggestionID == suggestion.id }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(suggestion.name)
                .font(.callout.weight(.semibold))
                .accessibilityIdentifier("pages.suggestion.\(suggestion.id).name")
            Text(suggestion.audience)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: Spacing.small, lineSpacing: Spacing.xxSmall) {
                ForEach(Array(suggestion.evidenceTitles.enumerated()), id: \.offset) { _, title in
                    Pill(text: title, style: .outline)
                }
                if !notOffered.isEmpty {
                    notOfferedPill
                }
                Button(isExpanded ? "Show Less" : "Show What’s in It") {
                    viewModel.expandedSuggestionID = isExpanded ? nil : suggestion.id
                }
                .buttonStyle(.link)
                .controlSize(.small)
                .accessibilityIdentifier("pages.suggestion.\(suggestion.id).show")
            }
        }
    }

    /// The languages whose text Atlas stopped.
    private var notOffered: [ProductPageTextSuggestion] { suggestion.notOfferedTexts ?? [] }

    /// "2 languages · Not offered".
    private var notOfferedPill: some View {
        let count = notOffered.count
        let languages = count == 1
            ? ProductPageChangeBuilder.localeName(notOffered[0].locale)
            : String(localized: "\(count) languages")
        return HStack(spacing: Spacing.xxSmall) {
            Text(languages)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
            Pill(text: String(localized: "Not offered"), style: .warning)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(languages): text not offered"))
        .accessibilityIdentifier("pages.suggestion.\(suggestion.id).notOffered")
    }

    private var actions: some View {
        HStack(spacing: Spacing.xSmall) {
            Button("Dismiss") { viewModel.dismissPage(suggestion) }
                .accessibilityIdentifier("pages.suggestion.\(suggestion.id).dismiss")
            Button("Accept") { viewModel.acceptPage(suggestion) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("pages.suggestion.\(suggestion.id).accept")
        }
        .controlSize(.small)
        .fixedSize()
    }
}
