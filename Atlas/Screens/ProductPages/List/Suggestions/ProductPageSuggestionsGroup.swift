//
//  ProductPageSuggestionsGroup.swift
//  Atlas
//

import SwiftUI

/// The pages an assistant suggested (board 53), above the list: who each
/// is for and why, what's in it on request, and Dismiss or Accept. Accept
/// All takes them all as drafts in one step (Pro).
struct ProductPageSuggestionsGroup: View {
    @Bindable var viewModel: ProductPagesViewModel
    let isCompact: Bool

    @Environment(ProGate.self) private var pro: ProGate?
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let suggestions = viewModel.pageSuggestions
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.small) {
                Text(viewModel.pageSuggestionsTitle)
                    .font(.body.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("pages.suggestions.title")
                if let source = suggestions.first?.source {
                    SuggestionSourceTag(source: .assistant(client: source))
                }
                Spacer(minLength: Spacing.small)
                if suggestions.count > 1 {
                    Button {
                        pro.require(.acceptAllPages(suggestions: suggestions.count, pages: suggestions.count)) {
                            viewModel.acceptAllPages()
                        }
                    } label: {
                        HStack(spacing: Spacing.xSmall) {
                            Text("Accept All")
                            SuggestionBadge(count: suggestions.count, isSmall: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.regular)
                    .accessibilityLabel(Text("Accept all \(suggestions.count) suggested pages"))
                    .accessibilityIdentifier("pages.suggestions.acceptAll")
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, 10)
            ForEach(suggestions) { suggestion in
                Divider().overlay(Palette.aiMark.opacity(0.25))
                ProductPageSuggestionRow(viewModel: viewModel, suggestion: suggestion, isCompact: isCompact)
            }
            Divider().overlay(Palette.aiMark.opacity(0.25))
            Text("Accepting makes a draft page in Atlas. You still push it and submit it to App Review yourself.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
        }
        .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.aiMark.opacity(contrast == .increased ? 0.8 : 0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.suggestions")
    }
}
